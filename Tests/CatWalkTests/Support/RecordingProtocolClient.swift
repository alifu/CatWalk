//
//  RecordingProtocolClient.swift
//  CatWalk
//

import Foundation
@testable import CatWalk

/// Stands in for the app's URLSession: answers forwarded challenges through their sender.
final class RecordingProtocolClient: NSObject, URLProtocolClient, @unchecked Sendable {

    enum Answer: Sendable {
        case useCredential, cancel, performDefaultHandling, continueWithoutCredential, rejectProtectionSpace
    }

    private let answer: Answer?
    private let challenges = CWLocked(0)

    /// - Parameter answer: `nil` leaves challenges unanswered.
    init(answer: Answer?) {
        self.answer = answer
    }

    var challengeCount: Int {
        challenges.withLock { $0 }
    }

    func urlProtocol(_ protocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {
        challenges.withLock { $0 += 1 }
        guard let answer, let sender = challenge.sender else { return }

        switch answer {
        case .useCredential:
            sender.use(URLCredential(trust: challenge.protectionSpace.serverTrust!), for: challenge)
        case .cancel:
            sender.cancel(challenge)
        case .performDefaultHandling:
            sender.performDefaultHandling?(for: challenge)
        case .continueWithoutCredential:
            sender.continueWithoutCredential(for: challenge)
        case .rejectProtectionSpace:
            sender.rejectProtectionSpaceAndContinue?(with: challenge)
        }
    }

    func urlProtocol(_ protocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {}
    func urlProtocol(_ protocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}
    func urlProtocol(_ protocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {}
    func urlProtocol(_ protocol: URLProtocol, didLoad data: Data) {}
    func urlProtocolDidFinishLoading(_ protocol: URLProtocol) {}
    func urlProtocol(_ protocol: URLProtocol, didFailWithError error: any Error) {}
    func urlProtocol(_ protocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}

/// Original sender of fixture challenges; CatWalk must replace it with itself.
final class StubChallengeSender: NSObject, URLAuthenticationChallengeSender, @unchecked Sendable {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
