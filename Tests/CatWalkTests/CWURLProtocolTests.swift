#if CATWALK_ENABLED
//
//  CWURLProtocolTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

/// End-to-end capture through a real `URLSession`; serialized because the engine is process-wide.
extension SharedEngine {

    @Suite("CWURLProtocol integration", .serialized)
    final class CWURLProtocolTests {

        let engine = CWCaptureEngine.shared
        private let baseURL = URL(string: "https://stub.test")!
        private let session: URLSession

        init() {
            StubURLProtocol.reset()
            engine.store.removeAll()
            engine.certificates.removeAll()
            engine.mocks.removeAll()
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
            CWCaptureEngine.shared.mocks.removeAll()
        }

        // MARK: - Mocking

        @Test("a mock answers without touching the network and is recorded as mocked")
        func mockedResponse() async throws {
            StubURLProtocol.stub("/products", .response(status: 500, headers: [:], body: Data("real".utf8)))
            let rule = CWMockRule.get("/products").respond(status: 200, json: ["ok": true])
            try CatWalk.mock(rule)

            let (data, response) = try await session.data(from: baseURL.appendingPathComponent("products"))

            let transaction = try #require(engine.store.snapshot().first)
            #expect((response as? HTTPURLResponse)?.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == #"{"ok":true}"#)
            #expect(StubURLProtocol.receivedBody(for: "/products") == nil)
            #expect(transaction.state == .mocked)
            #expect(transaction.isMocked)
            #expect(transaction.response?.body?.data == data)
            #expect(CatWalk.mockHitCount(id: rule.id) == 1)
        }

        @Test("a disabled mock lets the request through to the network")
        func disabledMockPassesThrough() async throws {
            StubURLProtocol.stub("/products", .response(status: 200, headers: [:], body: Data("real".utf8)))
            let rule = CWMockRule.get("/products").respond(status: 418)
            try CatWalk.mock(rule.enabled(false))

            let (data, _) = try await session.data(from: baseURL.appendingPathComponent("products"))

            #expect(String(data: data, encoding: .utf8) == "real")
            #expect(engine.store.snapshot().first?.state == .completed)
        }

        @Test("an error mock fails the request with that URLError")
        func mockedError() async throws {
            try CatWalk.mock(CWMockRule.get("/offline").fail(with: .notConnectedToInternet))

            await #expect(throws: URLError.self) {
                _ = try await self.session.data(from: self.baseURL.appendingPathComponent("offline"))
            }

            let transaction = try #require(engine.store.snapshot().first)
            #expect(transaction.state == .mocked)
            #expect(transaction.error?.code == URLError.notConnectedToInternet.rawValue)
        }

        @Test("network loads carry a timing breakdown, redirect hops included")
        func timing() async throws {
            StubURLProtocol.stub("/old", .redirect(to: baseURL.appendingPathComponent("new")))
            StubURLProtocol.stub("/new", .response(status: 200, headers: [:], body: Data("done".utf8)))

            _ = try await session.data(from: baseURL.appendingPathComponent("old"))

            try await Task.sleep(nanoseconds: 200_000_000)
            let hops = engine.store.snapshot().filter { $0.request.url.host == "stub.test" }
            #expect(hops.map(\.request.url.path) == ["/new", "/old"])
            #expect(hops.map { $0.timing != nil } == [true, true])
        }

        @Test("a mocked answer is timed as the rule's delay")
        func mockedTiming() async throws {
            try CatWalk.mock(CWMockRule.get("/fast").respond(delay: 0.1))

            _ = try await session.data(from: baseURL.appendingPathComponent("fast"))

            let timing = try #require(engine.store.snapshot().first?.timing)
            #expect(timing.fetchType == .mocked)
            #expect(timing.waiting?.duration == 0.1)
        }

        @Test("the mock delay is honoured")
        func mockedDelay() async throws {
            try CatWalk.mock(CWMockRule.get("/slow").respond(delay: 0.3))

            let started = Date()
            _ = try await session.data(from: baseURL.appendingPathComponent("slow"))

            #expect(Date().timeIntervalSince(started) >= 0.25)
            #expect(try #require(engine.store.snapshot().first).duration ?? 0 >= 0.25)
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

            let snapshot = engine.store.snapshot().filter { $0.request.url.host == "stub.test" }
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

        @Test("the load-time bootstrap captures sessions created before start")
        func earlySession() async throws {
            #expect(CWBootstrap.didRunAtLoad)
            engine.stop()
            CWSessionConfigurationSwizzle.setInjecting(true)
            let early = URLSession(configuration: .ephemeral)
            defer { early.invalidateAndCancel() }
            StubURLProtocol.stub("/early", .response(status: 200, headers: [:], body: Data("ok".utf8)))

            engine.start(
                configuration: CWConfiguration(interceptCustomSessions: false),
                upstreamProtocolClasses: [StubURLProtocol.self]
            )
            _ = try await early.data(from: baseURL.appendingPathComponent("early"))

            let catWalk = ObjectIdentifier(CWURLProtocol.self)
            let captured = engine.store.snapshot().filter { $0.request.url.path == "/early" }
            #expect(captured.count == 1)
            #expect(URLSessionConfiguration.ephemeral.protocolClasses?.contains { ObjectIdentifier($0) == catWalk } == false)
        }

        @Test("ignored hosts are not intercepted, others still are")
        func ignoredHosts() throws {
            let ignored = URLRequest(url: try #require(URL(string: "https://cdn.analytics.test/p")))
            let kept = URLRequest(url: try #require(URL(string: "https://api.test/p")))

            try CatWalk.ignore(host: "*.analytics.test")

            #expect(!CWURLProtocol.canInit(with: ignored))
            #expect(CWURLProtocol.canInit(with: kept))
            #expect(CatWalk.ignoredHosts == ["*.analytics.test"])

            try CatWalk.unignore(host: "*.analytics.test")
            #expect(CWURLProtocol.canInit(with: ignored))
        }

        @Test("ignoredHosts in the configuration apply on start; invalid ones are skipped")
        func configuredIgnoredHosts() throws {
            engine.start(
                configuration: CWConfiguration(interceptCustomSessions: false, ignoredHosts: ["a.test", "*.com"]),
                upstreamProtocolClasses: [StubURLProtocol.self]
            )

            #expect(CatWalk.ignoredHosts == ["a.test"])
        }

        @Test("an ignored host is passed straight through and never recorded")
        func ignoredNotRecorded() async throws {
            try CatWalk.ignore(host: "stub.test")

            _ = try? await session.data(from: baseURL.appendingPathComponent("anything"))

            #expect(engine.store.count == 0)
        }

        @Test("invalid host rules throw")
        func invalidRule() {
            #expect(throws: CWConfigurationError.invalidHost("*.com")) {
                try CatWalk.ignore(host: "*.com")
            }
        }

        // MARK: - TLS

        private func finished(path: String, timeout: TimeInterval = 2) async -> CWTransaction? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let done = engine.store.snapshot().first(where: { $0.request.url.path == path && $0.state != .inFlight }) {
                    return done
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return nil
        }

        private func pinnedSession(_ answer: PinningDelegate.Answer) -> (URLSession, PinningDelegate) {
            let delegate = PinningDelegate(answer: answer)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [CWURLProtocol.self]
            return (URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil), delegate)
        }

        @Test("a cancelling delegate (pinning failure) fails the load")
        func pinningRejects() async throws {
            StubURLProtocol.stub("/pinned", .serverTrust(
                certificates: [CertificateFixtures.rsaDER],
                then: .response(status: 200, headers: [:], body: Data())
            ))
            let (pinned, delegate) = pinnedSession(.reject)
            defer { pinned.invalidateAndCancel() }

            await #expect(throws: URLError.self) {
                _ = try await pinned.data(from: self.baseURL.appendingPathComponent("pinned"))
            }

            // The app sees the error first; the upstream cancellation is recorded just after.
            let transaction = try #require(await finished(path: "/pinned"))
            #expect(delegate.seenHosts == ["stub.test"])
            #expect(transaction.state == .failed)
            #expect(transaction.tls?.trustDecision == .cancelled)
        }

        @Test("without a delegate the system default handling is used")
        func defaultHandling() async throws {
            StubURLProtocol.stub("/plain", .serverTrust(
                certificates: [CertificateFixtures.ecDER],
                then: .response(status: 204, headers: [:], body: Data())
            ))

            _ = try await session.data(from: baseURL.appendingPathComponent("plain"))

            #expect(StubURLProtocol.challengeAnswers == [.defaultHandling])
            #expect(engine.store.snapshot().first?.tls?.trustDecision == .defaultHandling)
        }

        // MARK: - Challenge forwarding (driven directly: URLSession drops injected test trusts)

        private func startHangingLoad(_ path: String, client: RecordingProtocolClient) -> CWURLProtocol {
            StubURLProtocol.stub("/" + path, .hang)
            let request = URLRequest(url: baseURL.appendingPathComponent(path))
            let load = CWURLProtocol(request: request, cachedResponse: nil, client: client)
            load.startLoading()
            return load
        }

        private func fixtureChallenge(_ der: Data) -> URLAuthenticationChallenge {
            let trust = CertificateFixtures.trust([SecCertificateCreateWithData(nil, der as CFData)!])
            return URLAuthenticationChallenge(
                protectionSpace: StubTrustProtectionSpace(host: "stub.test", port: 443, trust: trust),
                proposedCredential: nil,
                previousFailureCount: 0,
                failureResponse: nil,
                error: nil,
                sender: StubChallengeSender()
            )
        }

        @Test("the app's answer is relayed upstream and the chain is recorded", arguments: [
            (RecordingProtocolClient.Answer.useCredential, URLSession.AuthChallengeDisposition.useCredential, CWTrustDecision.usedCredential),
            (.cancel, .cancelAuthenticationChallenge, .cancelled),
            (.performDefaultHandling, .performDefaultHandling, .defaultHandling),
            (.continueWithoutCredential, .performDefaultHandling, .defaultHandling),
            (.rejectProtectionSpace, .rejectProtectionSpace, .rejectedProtectionSpace),
        ])
        func forwarding(
            answer: RecordingProtocolClient.Answer,
            expected: URLSession.AuthChallengeDisposition,
            decision: CWTrustDecision
        ) throws {
            let client = RecordingProtocolClient(answer: answer)
            let load = startHangingLoad("forward", client: client)
            defer { load.stopLoading() }
            let upstream = CWLocked<URLSession.AuthChallengeDisposition?>(nil)

            load.bridgeDidReceive(fixtureChallenge(CertificateFixtures.rsaDER)) { disposition, _ in
                upstream.withLock { $0 = disposition }
            }
            load.bridgeDidComplete(with: nil)

            let transaction = try #require(engine.store.snapshot().first)
            #expect(client.challengeCount == 1)
            #expect(upstream.withLock { $0 } == expected)
            #expect(transaction.tls?.trustDecision == decision)
            #expect(transaction.tls?.certificates.map(\.summary) == ["rsa.catwalk.test"])
            #expect(transaction.tls?.isChainFromEarlierConnection == false)
        }

        @Test("a pending challenge is cancelled upstream when the load stops")
        func stopCancelsChallenge() {
            let client = RecordingProtocolClient(answer: nil)
            let load = startHangingLoad("stopped", client: client)
            let upstream = CWLocked<URLSession.AuthChallengeDisposition?>(nil)

            load.bridgeDidReceive(fixtureChallenge(CertificateFixtures.rsaDER)) { disposition, _ in
                upstream.withLock { $0 = disposition }
            }
            load.stopLoading()

            #expect(upstream.withLock { $0 } == .cancelAuthenticationChallenge)
        }

        @Test("a load without a handshake reuses the chain seen earlier for that host")
        func cachedChain() throws {
            let first = startHangingLoad("first", client: RecordingProtocolClient(answer: .performDefaultHandling))
            first.bridgeDidReceive(fixtureChallenge(CertificateFixtures.ecDER)) { _, _ in }
            first.bridgeDidComplete(with: nil)
            first.stopLoading()

            let second = startHangingLoad("second", client: RecordingProtocolClient(answer: nil))
            second.bridgeDidComplete(with: nil)
            second.stopLoading()

            let transaction = try #require(engine.store.snapshot().first)
            #expect(transaction.request.url.path == "/second")
            #expect(transaction.tls?.isChainFromEarlierConnection == true)
            #expect(transaction.tls?.certificates.first?.summary == "ec.catwalk.test")
            #expect(transaction.tls?.trustDecision == nil)
        }

        @Test("plain HTTP has no TLS info")
        func plainHTTP() async throws {
            StubURLProtocol.stub("/http", .response(status: 200, headers: [:], body: Data()))

            _ = try await session.data(from: try #require(URL(string: "http://stub.test/http")))

            #expect(engine.store.snapshot().first?.tls == nil)
        }
    }
}

/// App-side delegate standing in for an SSL-pinning implementation.
final class PinningDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    enum Answer { case accept, reject }

    private let answer: Answer
    private let hosts = CWLocked<[String]>([])

    init(answer: Answer) {
        self.answer = answer
    }

    var seenHosts: [String] {
        hosts.withLock { $0 }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        hosts.withLock { $0.append(challenge.protectionSpace.host) }
        guard answer == .accept, let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
#endif
