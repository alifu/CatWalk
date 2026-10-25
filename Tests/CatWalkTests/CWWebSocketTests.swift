#if CATWALK_ENABLED
//
//  CWWebSocketTests.swift
//  CatWalk
//
//  Real `URLSessionWebSocketTask`s against a loopback echo server (`WebSocketEchoServer`).
//

import Foundation
import Testing
@testable import CatWalk

extension SharedEngine {

    @Suite("WebSockets", .serialized)
    final class CWWebSocketTests {

        let engine = CWCaptureEngine.shared
        private let server: WebSocketEchoServer
        /// Created before `start`, like an app's session: load-time injection must not break it.
        private let session = URLSession(configuration: .ephemeral)

        init() throws {
            server = try WebSocketEchoServer()
        }

        deinit {
            session.invalidateAndCancel()
            server.stop()
            CWCaptureEngine.shared.stop()
        }

        private func start(_ configuration: CWConfiguration = CWConfiguration(interceptCustomSessions: false, triggers: [])) {
            engine.start(configuration: configuration)
        }

        /// Polls until the row for `url` satisfies `condition` (the store is written from URLSession queues).
        private func transaction(for url: URL, where condition: (CWTransaction) -> Bool = { _ in true }) async -> CWTransaction? {
            for _ in 0..<150 {
                if let found = engine.store.snapshot().first(where: { $0.request.url == url }), condition(found) {
                    return found
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            return engine.store.snapshot().first { $0.request.url == url }
        }

        private func echo(_ message: URLSessionWebSocketTask.Message, on task: URLSessionWebSocketTask) async throws {
            try await task.send(message)
            _ = try await task.receive()
        }

        @Test("async send/receive: handshake, 8 frames in order, app close code and budget")
        func echoAsync() async throws {
            start()
            let url = try await server.start()
            let task = session.webSocketTask(with: url)
            task.resume()

            for text in ["one", "two", "three"] {
                try await echo(.string(text), on: task)
            }
            try await echo(.data(Data([1, 2, 3])), on: task)
            task.cancel(with: .goingAway, reason: Data("bye".utf8))

            let socket = try #require(await transaction(for: url) { $0.state != .inFlight })
            let log = try #require(socket.webSocket)
            #expect(socket.source == .webSocket)
            #expect(socket.state == .completed)
            #expect(socket.response?.statusCode == 101)
            #expect(socket.response?.headers["Upgrade"]?.lowercased() == "websocket")
            #expect(log.frames.map(\.direction) == [.sent, .received, .sent, .received, .sent, .received, .sent, .received])
            #expect(log.frames.map(\.kind) == [.text, .text, .text, .text, .text, .text, .binary, .binary])
            #expect(log.frames.first?.payload?.data == Data("one".utf8))
            #expect(log.closeCode == 1001)
            #expect(log.closeReason == "bye")
            #expect(socket.storedBodyBytes == 2 * (3 + 3 + 5 + 3))
        }

        @Test("regression: a session with CWURLProtocol leaves the WebSocket handshake alone")
        func injectedSession() async throws {
            start()
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [CWURLProtocol.self]
            let injected = URLSession(configuration: configuration)
            defer { injected.invalidateAndCancel() }
            let url = try await server.start()
            let task = injected.webSocketTask(with: url)
            task.resume()

            try await echo(.string("through"), on: task)
            task.cancel()

            let rows = engine.store.snapshot().filter { $0.request.url.port == url.port && $0.request.url.path == url.path }
            #expect(rows.count == 1)
            #expect(rows.first?.source == .webSocket)
        }

        @Test("completion-handler send/receive are captured too")
        func echoCompletionHandlers() async throws {
            start()
            let url = try await server.start()
            let task = session.webSocketTask(with: url)
            task.resume()

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                task.send(.string(#"{"hello":"json"}"#)) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                task.receive { continuation.resume(with: $0.map { _ in () }) }
            }
            task.cancel()

            let log = try #require(await transaction(for: url) { $0.state != .inFlight }?.webSocket)
            #expect(log.frames.count == 2)
            #expect(log.frames.last?.direction == .received)
            #expect(log.closeCode == nil)
        }

        @Test("ping and pong are recorded")
        func ping() async throws {
            start()
            let url = try await server.start()
            let task = session.webSocketTask(with: url)
            task.resume()

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                task.sendPing { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            task.cancel()

            let log = try #require(await transaction(for: url) { $0.state != .inFlight }?.webSocket)
            #expect(log.frames.map(\.kind) == [.ping, .pong])
            #expect(log.frames.map(\.direction) == [.sent, .received])
        }

        @Test("a close from the server ends the row with its code and reason")
        func serverClose() async throws {
            start()
            let url = try await server.start()
            let task = session.webSocketTask(with: url)
            task.resume()

            try await task.send(.string(WebSocketEchoServer.closeCommand))
            await #expect(throws: (any Error).self) { _ = try await task.receive() }

            let socket = try #require(await transaction(for: url) { $0.state != .inFlight })
            #expect(socket.state == .completed)
            #expect(socket.webSocket?.closeCode == Int(WebSocketEchoServer.closeCode))
            #expect(socket.webSocket?.closeReason == WebSocketEchoServer.closeReason)
        }

        @Test("nothing is recorded with captureWebSockets off or for an ignored host")
        func optOut() async throws {
            let url = try await server.start()
            for configuration in [
                CWConfiguration(interceptCustomSessions: false, triggers: [], captureWebSockets: false),
                CWConfiguration(interceptCustomSessions: false, ignoredHosts: ["127.0.0.1"], triggers: []),
            ] {
                start(configuration)
                let task = session.webSocketTask(with: url)
                task.resume()
                try await echo(.string("quiet"), on: task)
                task.cancel()
            }

            #expect(engine.store.snapshot().allSatisfy { $0.request.url != url })
        }

        @Test("a stopped engine records nothing; the app still gets its messages")
        func stoppedEngine() async throws {
            start()
            let stopped = CWCaptureEngine()
            let url = try await server.start()
            let task = session.webSocketTask(with: url)

            CWWebSocketRecorder.didResume(task, engine: stopped)
            task.resume()
            try await echo(.string("still works"), on: task)
            task.cancel()

            #expect(stopped.store.count == 0)
        }
    }
}
#endif
