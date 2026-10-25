#if CATWALK_ENABLED
//
//  CWBackgroundSessionTests.swift
//  CatWalk
//
//  Background transfers cannot run inside a unit test, so these tests mark a foreground session
//  (served by `StubURLProtocol`, without `CWURLProtocol`) as observed and drive real delegate callbacks.
//

import Foundation
import Testing
@testable import CatWalk

extension SharedEngine {

    @Suite("Background sessions", .serialized)
    final class CWBackgroundSessionTests {

        let engine = CWCaptureEngine.shared
        private let baseURL = URL(string: "https://bg.test")!

        init() {
            StubURLProtocol.reset()
            engine.start(
                configuration: CWConfiguration(interceptCustomSessions: false, triggers: []),
                upstreamProtocolClasses: [StubURLProtocol.self]
            )
        }

        deinit {
            CWCaptureEngine.shared.stop()
        }

        private func observedSession(delegate: URLSessionDelegate, observe: Bool = true) -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            if observe {
                CWBackgroundSessionHook.observe(session, delegate: delegate)
            }
            return session
        }

        private func recorded(_ path: String) async -> CWTransaction? {
            for _ in 0..<100 {
                if let found = engine.store.snapshot().first(where: { $0.request.url.host == "bg.test" && $0.request.url.path == path }) {
                    return found
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            return nil
        }

        @Test("a background configuration marks the session and hooks its delegate class")
        func factoryHook() throws {
            let delegate = CompletionDelegate()
            let background = URLSession(
                configuration: .background(withIdentifier: "com.catwalk.tests.\(UUID().uuidString)"),
                delegate: delegate,
                delegateQueue: nil
            )
            let foreground = URLSession(configuration: .ephemeral, delegate: CompletionDelegate(), delegateQueue: nil)
            defer {
                background.invalidateAndCancel()
                foreground.invalidateAndCancel()
            }

            #expect(CWBackgroundSessionHook.isObserved(background))
            #expect(!CWBackgroundSessionHook.isObserved(foreground))
            #expect(background.delegate === delegate)
        }

        @Test("download: body read before the app moves the file; the app still gets it")
        func download() async throws {
            let payload = Data((0..<5_000).map { UInt8(truncatingIfNeeded: $0) })
            StubURLProtocol.stub("/file", .response(status: 200, headers: ["Content-Type": "application/octet-stream"], body: payload))
            let delegate = DownloadDelegate()
            let session = observedSession(delegate: delegate)
            defer { session.invalidateAndCancel() }

            await delegate.run { session.downloadTask(with: self.baseURL.appendingPathComponent("file")).resume() }

            let transaction = try #require(await recorded("/file"))
            #expect(delegate.movedData == payload)
            #expect(transaction.source == .backgroundSession)
            #expect(transaction.response?.statusCode == 200)
            #expect(transaction.response?.body?.data == payload)
            #expect(transaction.response?.body?.totalBytes == payload.count)
            #expect(transaction.timing != nil)
        }

        @Test("data: received bytes are captured once, and the callback app implements still runs")
        func data() async throws {
            StubURLProtocol.stub("/json", .response(status: 201, headers: [:], body: Data(#"{"ok":1}"#.utf8)))
            let delegate = DataDelegate()
            let session = observedSession(delegate: delegate)
            defer { session.invalidateAndCancel() }

            await delegate.run { session.dataTask(with: self.baseURL.appendingPathComponent("json")).resume() }

            let transaction = try #require(await recorded("/json"))
            #expect(delegate.received == Data(#"{"ok":1}"#.utf8))
            #expect(transaction.response?.body?.data == delegate.received)
            #expect(engine.store.snapshot().filter { $0.id == transaction.id }.count == 1)
        }

        @Test("upload: the request body is the prefix of the uploaded file")
        func upload() async throws {
            StubURLProtocol.stub("/upload", .response(status: 204, headers: [:], body: Data()))
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("catwalk-upload-\(UUID().uuidString)")
            try Data("hello upload".utf8).write(to: file)
            defer { try? FileManager.default.removeItem(at: file) }
            var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
            request.httpMethod = "POST"
            let delegate = CompletionDelegate()
            let session = observedSession(delegate: delegate)
            defer { session.invalidateAndCancel() }

            await delegate.run { session.uploadTask(with: request, fromFile: file).resume() }

            let transaction = try #require(await recorded("/upload"))
            #expect(transaction.request.method == "POST")
            #expect(transaction.request.body?.data == Data("hello upload".utf8))
        }

        @Test("failures are recorded with the error")
        func failure() async throws {
            StubURLProtocol.stub("/down", .failure(.timedOut))
            let delegate = CompletionDelegate()
            let session = observedSession(delegate: delegate)
            defer { session.invalidateAndCancel() }

            await delegate.run { session.dataTask(with: self.baseURL.appendingPathComponent("down")).resume() }

            let transaction = try #require(await recorded("/down"))
            #expect(transaction.state == .failed)
            #expect(transaction.error?.code == URLError.timedOut.rawValue)
        }

        @Test("unobserved sessions sharing a hooked delegate class record nothing")
        func unobserved() async throws {
            StubURLProtocol.stub("/plain", .response(status: 200, headers: [:], body: Data("x".utf8)))
            let hooked = observedSession(delegate: CompletionDelegate())
            let plainDelegate = CompletionDelegate()
            let plain = observedSession(delegate: plainDelegate, observe: false)
            defer {
                hooked.invalidateAndCancel()
                plain.invalidateAndCancel()
            }

            await plainDelegate.run { plain.dataTask(with: self.baseURL.appendingPathComponent("plain")).resume() }

            try await Task.sleep(nanoseconds: 200_000_000)
            #expect(engine.store.snapshot().filter { $0.request.url.host == "bg.test" && $0.request.url.path == "/plain" }.isEmpty)
        }

        @Test("an engine that is not running records nothing")
        func notRunning() async throws {
            StubURLProtocol.stub("/stopped", .response(status: 200, headers: [:], body: Data("x".utf8)))
            let stopped = CWCaptureEngine()
            let session = observedSession(delegate: CompletionDelegate(), observe: false)
            defer { session.invalidateAndCancel() }
            let task = session.dataTask(with: baseURL.appendingPathComponent("stopped"))

            CWBackgroundRecorder.didComplete(task, error: nil, engine: stopped)

            #expect(stopped.store.snapshot().isEmpty)
        }

        @Test("hooks keep responds(to:) for callbacks the app does not implement")
        func respondsParity() {
            let delegate = CompletionDelegate()
            let session = observedSession(delegate: delegate)
            defer { session.invalidateAndCancel() }

            #expect(!delegate.responds(to: NSSelectorFromString("URLSession:dataTask:didReceiveData:")))
            #expect(!delegate.responds(to: NSSelectorFromString("URLSession:downloadTask:didFinishDownloadingToURL:")))
            #expect(!delegate.responds(to: NSSelectorFromString("URLSession:task:didReceiveChallenge:completionHandler:")))
            #expect(delegate.responds(to: NSSelectorFromString("URLSession:task:didCompleteWithError:")))
        }
    }
}

// MARK: - Delegates (one class per behaviour: hooks are per class)

/// Signals when the task completes. Implements completion only.
class CompletionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    private var continuation: CheckedContinuation<Void, Never>?
    private let lock = NSLock()

    func run(_ start: () -> Void) async {
        await withCheckedContinuation { continuation in
            lock.withLock { self.continuation = continuation }
            start()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        lock.withLock {
            continuation?.resume()
            continuation = nil
        }
    }
}

final class DownloadDelegate: CompletionDelegate, URLSessionDownloadDelegate, @unchecked Sendable {

    private(set) var movedData: Data?

    /// Moves the file away, as apps do; CatWalk must have read it before this runs.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("catwalk-moved-\(UUID().uuidString)")
        try? FileManager.default.moveItem(at: location, to: destination)
        movedData = try? Data(contentsOf: destination)
        try? FileManager.default.removeItem(at: destination)
    }
}

final class DataDelegate: CompletionDelegate, URLSessionDataDelegate, @unchecked Sendable {

    private(set) var received = Data()

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        received.append(data)
    }
}
#endif
