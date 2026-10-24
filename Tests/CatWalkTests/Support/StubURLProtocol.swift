#if CATWALK_ENABLED
//
//  StubURLProtocol.swift
//  CatWalk
//

import Foundation
@testable import CatWalk

/// Upstream stand-in for the network, keyed by URL path.
final class StubURLProtocol: URLProtocol, URLAuthenticationChallengeSender, @unchecked Sendable {

    indirect enum Reply: Sendable {
        case response(status: Int, headers: [String: String], body: Data)
        case redirect(to: URL)
        case failure(URLError.Code)
        /// Sends a server-trust challenge for these DER certificates, then `then` unless cancelled.
        case serverTrust(certificates: [Data], then: Reply)
        /// Never answers; the test drives the load itself.
        case hang
    }

    enum Answer: Equatable, Sendable {
        case credential, withoutCredential, cancelled, defaultHandling, rejected
    }

    private static let answers = CWLocked<[Answer]>([])

    /// What the session answered to stubbed challenges, in order.
    static var challengeAnswers: [Answer] {
        answers.withLock { $0 }
    }

    private let afterChallenge = CWLocked<Reply?>(nil)

    private static let replies = CWLocked<[String: Reply]>([:])
    private static let receivedBodies = CWLocked<[String: Data]>([:])

    static func stub(_ path: String, _ reply: Reply) {
        replies.withLock { $0[path] = reply }
    }

    static func receivedBody(for path: String) -> Data? {
        receivedBodies.withLock { $0[path] }
    }

    static func reset() {
        replies.withLock { $0.removeAll() }
        receivedBodies.withLock { $0.removeAll() }
        answers.withLock { $0.removeAll() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }

        let body = request.httpBody ?? request.httpBodyStream.flatMap { try? CWBodyReader.read($0) }
        Self.receivedBodies.withLock { $0[url.path] = body }

        let reply = Self.replies.withLock { $0[url.path] }
            ?? .response(status: 404, headers: [:], body: Data())
        send(reply, for: url)
    }

    private func send(_ reply: Reply, for url: URL) {
        switch reply {
        case let .response(status, headers, body):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)

        case let .redirect(target):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": target.absoluteString]
            )!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)

        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))

        case .hang:
            break

        case let .serverTrust(certificates, then):
            afterChallenge.withLock { $0 = then }
            let trust = CertificateFixtures.trust(certificates.compactMap {
                SecCertificateCreateWithData(nil, $0 as CFData)
            })
            let space = StubTrustProtectionSpace(host: url.host ?? "", port: url.port ?? 443, trust: trust)
            let challenge = URLAuthenticationChallenge(
                protectionSpace: space,
                proposedCredential: nil,
                previousFailureCount: 0,
                failureResponse: nil,
                error: nil,
                sender: self
            )
            client?.urlProtocol(self, didReceive: challenge)
        }
    }

    override func stopLoading() {}

    // MARK: - URLAuthenticationChallengeSender

    private func answer(_ answer: Answer) {
        Self.answers.withLock { $0.append(answer) }
        guard let url = request.url, let next = afterChallenge.withLock({ $0 }) else { return }

        if answer == .cancelled {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
        } else {
            send(next, for: url)
        }
    }

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) { answer(.credential) }
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) { answer(.withoutCredential) }
    func cancel(_ challenge: URLAuthenticationChallenge) { answer(.cancelled) }
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) { answer(.defaultHandling) }
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) { answer(.rejected) }
}

/// Server-trust protection space carrying a fixture trust (the real one is read-only).
final class StubTrustProtectionSpace: URLProtectionSpace, @unchecked Sendable {

    private let trust: SecTrust

    init(host: String, port: Int, trust: SecTrust) {
        self.trust = trust
        super.init(
            host: host,
            port: port,
            protocol: NSURLProtectionSpaceHTTPS,
            realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var serverTrust: SecTrust? { trust }
}
#endif
