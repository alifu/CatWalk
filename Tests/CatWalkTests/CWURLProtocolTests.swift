//
//  CWURLProtocolTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

/// End-to-end capture through a real `URLSession`; serialized because the engine is process-wide.
@Suite("CWURLProtocol integration", .serialized)
final class CWURLProtocolTests {

    private let engine = CWCaptureEngine.shared
    private let baseURL = URL(string: "https://stub.test")!
    private let session: URLSession

    init() {
        StubURLProtocol.reset()
        engine.store.removeAll()
        engine.start(
            configuration: CWConfiguration(interceptCustomSessions: false),
            upstreamProtocolClasses: [StubURLProtocol.self]
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CWURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
        CWCaptureEngine.shared.stop()
        CWCaptureEngine.shared.store.removeAll()
    }

    @Test("captures a GET with response body and cookies")
    func capturesGet() async throws {
        StubURLProtocol.stub("/products", .response(
            status: 200,
            headers: ["Content-Type": "application/json", "Set-Cookie": "id=7; Path=/"],
            body: Data(#"{"ok":true}"#.utf8)
        ))

        let (data, _) = try await session.data(from: baseURL.appendingPathComponent("products"))

        let transaction = try #require(engine.store.snapshot().first)
        #expect(data == Data(#"{"ok":true}"#.utf8))
        #expect(transaction.state == .completed)
        #expect(transaction.request.method == "GET")
        #expect(transaction.response?.statusCode == 200)
        #expect(transaction.response?.body?.data == data)
        #expect(transaction.responseCookies.map(\.name) == ["id"])
    }

    @Test("captures and forwards a streamed POST body")
    func capturesStreamedPost() async throws {
        StubURLProtocol.stub("/upload", .response(status: 201, headers: [:], body: Data()))
        let payload = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0) })
        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: payload)

        _ = try await session.data(for: request)

        let transaction = try #require(engine.store.snapshot().first)
        #expect(StubURLProtocol.receivedBody(for: "/upload") == payload)
        #expect(transaction.request.body?.data == payload)
        #expect(transaction.response?.statusCode == 201)
    }

    @Test("records each redirect hop and the client follows it")
    func followsRedirect() async throws {
        StubURLProtocol.stub("/old", .redirect(to: baseURL.appendingPathComponent("new")))
        StubURLProtocol.stub("/new", .response(status: 200, headers: [:], body: Data("done".utf8)))

        let (data, response) = try await session.data(from: baseURL.appendingPathComponent("old"))

        let snapshot = engine.store.snapshot()
        #expect(data == Data("done".utf8))
        #expect(response.url?.path == "/new")
        #expect(snapshot.map { $0.request.url.path } == ["/new", "/old"])
        #expect(snapshot.map { $0.response?.statusCode } == [200, 302])
    }

    @Test("records failures and passes the error to the client")
    func recordsFailure() async throws {
        StubURLProtocol.stub("/offline", .failure(.notConnectedToInternet))

        await #expect(throws: URLError.self) {
            _ = try await self.session.data(from: self.baseURL.appendingPathComponent("offline"))
        }

        let transaction = try #require(engine.store.snapshot().first)
        #expect(transaction.state == .failed)
        #expect(transaction.error?.code == URLError.notConnectedToInternet.rawValue)
    }

    @Test("only accepts http(s) while running")
    func canInitRules() throws {
        let https = URLRequest(url: baseURL)
        let data = URLRequest(url: try #require(URL(string: "data:text/plain,hi")))

        #expect(CWURLProtocol.canInit(with: https))
        #expect(!CWURLProtocol.canInit(with: data))

        engine.stop()

        #expect(!CWURLProtocol.canInit(with: https))
    }

    @Test("swizzle injects the protocol into default and ephemeral configurations")
    func swizzlesConfigurations() {
        engine.start(configuration: CWConfiguration(interceptCustomSessions: true))

        let catWalk = ObjectIdentifier(CWURLProtocol.self)
        #expect(URLSessionConfiguration.default.protocolClasses?.first.map(ObjectIdentifier.init) == catWalk)
        #expect(URLSessionConfiguration.ephemeral.protocolClasses?.first.map(ObjectIdentifier.init) == catWalk)
        #expect(URLSessionConfiguration.default.protocolClasses?.filter { ObjectIdentifier($0) == catWalk }.count == 1)
    }
}
