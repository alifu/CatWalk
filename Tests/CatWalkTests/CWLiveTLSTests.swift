//
//  CWLiveTLSTests.swift
//  CatWalk
//
//  Real-network checks, off by default. Run with:
//  TEST_RUNNER_CATWALK_LIVE_TESTS=1 xcodebuild test -scheme CatWalk -destination '…'
//

import Foundation
import Testing
@testable import CatWalk

extension CWURLProtocolTests {

    static let isLiveEnabled = ProcessInfo.processInfo.environment["CATWALK_LIVE_TESTS"] != nil
    private static let liveURL = URL(string: "https://dummyjson.com/products/1")!

    private func startLive() {
        engine.start(configuration: CWConfiguration(interceptCustomSessions: false))
    }

    private func liveSession(pinning delegate: SPKIPinningDelegate?) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CWURLProtocol.self]
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    @Test("live: app pinning sees the real trust and accepts; TLS details are captured",
          .enabled(if: CWURLProtocolTests.isLiveEnabled))
    func liveAcceptedPin() async throws {
        startLive()
        let delegate = SPKIPinningDelegate(expectedPin: nil)
        let session = liveSession(pinning: delegate)
        defer { session.invalidateAndCancel() }

        let (_, response) = try await session.data(from: Self.liveURL)

        let transaction = try #require(engine.store.snapshot().first { $0.request.url == Self.liveURL })
        let tls = try #require(transaction.tls)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(delegate.observedPins.count == 1)
        #expect(tls.trustDecision == .usedCredential)
        #expect(["TLS 1.2", "TLS 1.3"].contains(tls.protocolName))
        #expect(tls.cipherSuiteName != nil)
        #expect(tls.certificates.count >= 2)
        #expect(tls.certificates.first?.publicKeySHA256 == delegate.observedPins.first)
        print("CatWalk live TLS:", tls.protocolName ?? "-", tls.cipherSuiteName ?? "-",
              tls.certificates.map { $0.summary ?? "?" })
    }

    @Test("live: a wrong pin in the app still blocks the request through CatWalk",
          .enabled(if: CWURLProtocolTests.isLiveEnabled))
    func liveRejectedPin() async throws {
        startLive()
        let session = liveSession(pinning: SPKIPinningDelegate(expectedPin: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="))
        defer { session.invalidateAndCancel() }

        await #expect(throws: URLError.self) {
            _ = try await session.data(from: Self.liveURL)
        }
    }
}

/// Typical app-side pinning: system evaluation, then compare the leaf SPKI SHA-256.
final class SPKIPinningDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    private let expectedPin: String?
    private let pins = CWLocked<[String]>([])

    /// - Parameter expectedPin: `nil` accepts any valid chain and just records the pin.
    init(expectedPin: String?) {
        self.expectedPin = expectedPin
    }

    var observedPins: [String] {
        pins.withLock { $0 }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust,
            SecTrustEvaluateWithError(trust, nil),
            let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first,
            let pin = CWCertificate(leaf).publicKeySHA256
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        pins.withLock { $0.append(pin) }

        if let expectedPin, expectedPin != pin {
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}
