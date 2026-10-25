#if CATWALK_ENABLED
//
//  CWURLProtocol.swift
//  CatWalk
//

import Foundation

/// Intercepts HTTP(S) loads, forwards them through `CWSessionBridge` and records them.
///
/// Not main-actor isolated: the URL loading system calls it on its own threads.
/// Mutable state lives in a lock; client callbacks are always made outside the lock.
///
/// Auth challenges are re-issued to the app's session with this protocol as sender, so the
/// app's own delegate (SSL pinning, client certificates, basic auth) still decides.
final class CWURLProtocol: URLProtocol, CWSessionBridgeClient, URLAuthenticationChallengeSender, @unchecked Sendable {

    private static let handledKey = "com.catwalk.handled"
    private static let supportedSchemes: Set<String> = ["http", "https"]

    private typealias ChallengeCompletion = @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

    private struct PendingChallenge {
        let challenge: URLAuthenticationChallenge
        let completion: ChallengeCompletion
    }

    private struct LoadState {
        var recorder: CWRecorder?
        var transaction: CWTransaction?
        var response: URLResponse?
        var responseBody = CWBodyAccumulator(limit: 0)
        var task: URLSessionDataTask?
        var pendingChallenge: PendingChallenge?
        var certificates: [CWCertificate] = []
        var trustDecision: CWTrustDecision?
        var connection: CWConnectionMetrics?
        var isStopped = false
        var isFinished = false
    }

    private let state = CWLocked(LoadState())
    private let engine = CWCaptureEngine.shared

    // MARK: - URLProtocol

    /// O(L): running flag, scheme set lookup, handled marker, ignored-host walk.
    override class func canInit(with request: URLRequest) -> Bool {
        guard
            CWCaptureEngine.shared.isRunning,
            let scheme = request.url?.scheme?.lowercased(),
            supportedSchemes.contains(scheme)
        else {
            return false
        }
        guard property(forKey: handledKey, in: request) == nil else { return false }
        return !CWCaptureEngine.shared.isIgnored(host: request.url?.host)
    }

    /// WebSocket handshakes arrive as `http(s)` requests; loading one here would replace the upgrade
    /// with a plain data task and break the socket. `CWWebSocketHook` observes those tasks instead.
    override class func canInit(with task: URLSessionTask) -> Bool {
        guard !CWWebSocketHook.isWebSocketTask(task), let request = task.currentRequest ?? task.originalRequest else {
            return false
        }
        return canInit(with: request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let recorder = engine.recorder

        let body: Data?
        do {
            body = try CWBodyReader.body(of: request)
        } catch {
            recordUnsentFailure(error, recorder: recorder)
            client?.urlProtocol(self, didFailWithError: error.clientError)
            return
        }

        guard
            let transaction = recorder.begin(request, body: body),
            let upstream = Self.upstreamRequest(from: request, body: body)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        engine.store.upsert(transaction)

        if let rule = engine.mocks.match(request) {
            answerWithMock(rule, recorder: recorder, transaction: transaction)
            return
        }

        let task = engine.bridge.makeTask(for: upstream, client: self)

        let isStopped = state.withLock { state in
            state.recorder = recorder
            state.transaction = transaction
            state.responseBody = CWBodyAccumulator(limit: recorder.configuration.maxBodyBytes)
            state.task = task
            return state.isStopped
        }

        if isStopped {
            task.cancel()
        } else {
            task.resume()
        }
    }

    override func stopLoading() {
        let (task, challenge) = state.withLock { state in
            state.isStopped = true
            defer { state.pendingChallenge = nil }
            return (state.task, state.pendingChallenge)
        }
        if let challenge {
            // URLSession stops the load, rather than calling `cancel(_:)`, when the app cancels a challenge.
            recordTrust(of: challenge.challenge, decision: .cancelled)
            challenge.completion(.cancelAuthenticationChallenge, nil)
        }
        task?.cancel()
    }

    // MARK: - CWSessionBridgeClient

    func bridgeDidReceive(_ response: URLResponse) {
        let shouldNotify = state.withLock { state in
            guard !state.isFinished else { return false }
            state.response = response
            return !state.isStopped
        }
        guard shouldNotify else { return }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    func bridgeDidReceive(_ data: Data) {
        let shouldNotify = state.withLock { state in
            guard !state.isFinished else { return false }
            state.responseBody.append(data)
            return !state.isStopped
        }
        guard shouldNotify else { return }

        client?.urlProtocol(self, didLoad: data)
    }

    /// Records the 3xx hop, hands the redirect to the app's session and ends this load
    /// (Apple's CustomHTTPProtocol pattern).
    func bridgeWillRedirect(to request: URLRequest, response: HTTPURLResponse) {
        guard recordCompletion(response: response, error: nil) else { return }

        client?.urlProtocol(self, wasRedirectedTo: Self.clientRequest(from: request), redirectResponse: response)
        client?.urlProtocol(self, didFailWithError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    func bridgeDidReceive(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let client else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let pending = PendingChallenge(challenge: challenge, completion: completionHandler)
        let previous = state.withLock { state -> PendingChallenge?? in
            guard !state.isFinished, !state.isStopped else { return .none }
            defer { state.pendingChallenge = pending }
            return .some(state.pendingChallenge)
        }
        guard let previous else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        previous?.completion(.cancelAuthenticationChallenge, nil)

        client.urlProtocol(self, didReceive: URLAuthenticationChallenge(authenticationChallenge: challenge, sender: self))
    }

    /// Usually arrives before completion. For a redirect hop it arrives after the hop was
    /// recorded, so the stored transaction is updated in place.
    func bridgeDidCollect(_ metrics: CWConnectionMetrics) {
        let snapshot = state.withLock { state -> LoadState? in
            state.connection = metrics
            return state.isFinished ? state : nil
        }
        guard let snapshot, let id = snapshot.transaction?.id else { return }

        let tls = snapshot.transaction.flatMap { tlsInfo(for: $0.request.url, from: snapshot) }
        engine.store.update(id: id) { $0.withConnectionDetails(tls: tls, timing: metrics.timing) }
    }

    func bridgeDidComplete(with error: (any Error)?) {
        guard recordCompletion(response: nil, error: error) else { return }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

// MARK: - URLAuthenticationChallengeSender

extension CWURLProtocol {

    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        resolveChallenge(.useCredential, credential: credential, decision: .usedCredential)
    }

    /// For server trust, "no credential" means the system evaluates trust (never weaker than default).
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        if Self.isServerTrust(challenge) {
            resolveChallenge(.performDefaultHandling, credential: nil, decision: .defaultHandling)
        } else {
            resolveChallenge(.useCredential, credential: nil, decision: nil)
        }
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        resolveChallenge(.cancelAuthenticationChallenge, credential: nil, decision: .cancelled)
    }

    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {
        resolveChallenge(.performDefaultHandling, credential: nil, decision: .defaultHandling)
    }

    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {
        resolveChallenge(.rejectProtectionSpace, credential: nil, decision: .rejectedProtectionSpace)
    }
}

private extension CWURLProtocol {

    static func isServerTrust(_ challenge: URLAuthenticationChallenge) -> Bool {
        challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
    }

    /// Records the server chain (after the app's own evaluation, which caches the result)
    /// and hands the app's answer to the upstream session.
    func resolveChallenge(
        _ disposition: URLSession.AuthChallengeDisposition,
        credential: URLCredential?,
        decision: CWTrustDecision?
    ) {
        guard let pending = state.withLock({ state in
            defer { state.pendingChallenge = nil }
            return state.pendingChallenge
        }) else { return }

        if let decision {
            recordTrust(of: pending.challenge, decision: decision)
        }
        pending.completion(disposition, credential)
    }

    /// Reads the chain after the app has answered, so its own evaluation (cached on the trust) has run.
    func recordTrust(of challenge: URLAuthenticationChallenge, decision: CWTrustDecision) {
        guard Self.isServerTrust(challenge) else { return }

        let space = challenge.protectionSpace
        let chain = space.serverTrust.map(CWCertificate.chain(of:)) ?? []
        engine.certificates.store(chain, for: CWCertificateCache.key(host: space.host, port: space.port))
        state.withLock { state in
            state.certificates = chain
            state.trustDecision = decision
        }
    }
}

// MARK: - Mocking

private extension CWURLProtocol {

    /// Answers from `rule` after its delay; the upstream network is never used.
    func answerWithMock(_ rule: CWMockRule, recorder: CWRecorder, transaction: CWTransaction) {
        state.withLock { state in
            state.recorder = recorder
            state.transaction = transaction
        }
        let finish: @Sendable () -> Void = { [self] in finishMock(rule.response, recorder: recorder, transaction: transaction) }

        if rule.response.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + rule.response.delay, execute: finish)
        } else {
            finish()
        }
    }

    func finishMock(_ mock: CWMockResponse, recorder: CWRecorder, transaction: CWTransaction) {
        let url = transaction.request.url
        let httpResponse = mock.error == nil ? CWMockResponder.httpResponse(for: mock, url: url) : nil
        let error: (any Error)? = mock.error.map { URLError($0) }

        let shouldNotify = state.withLock { state -> Bool? in
            guard !state.isFinished else { return nil }
            state.isFinished = true
            return !state.isStopped
        }
        guard let shouldNotify else { return }

        let body = mock.body.isEmpty ? nil : CWBody(capturing: mock.body, limit: recorder.configuration.maxBodyBytes)
        let completed = recorder.complete(transaction, response: httpResponse, body: body, error: error)
        engine.store.upsert(completed.markedMocked(timing: .mocked(startingAt: transaction.startDate, delay: mock.delay)))
        guard shouldNotify else { return }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else if let httpResponse {
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: mock.body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }
}

// MARK: - Recording

private extension CWURLProtocol {

    /// Stores the finished transaction exactly once.
    /// - Returns: `true` when the client should be told about the outcome.
    func recordCompletion(response: URLResponse?, error: (any Error)?) -> Bool {
        let pending = state.withLock { state -> (CWRecorder, CWTransaction, URLResponse?, CWBody?, LoadState)? in
            guard !state.isFinished, let recorder = state.recorder, let transaction = state.transaction else {
                return nil
            }
            state.isFinished = true
            return (recorder, transaction, response ?? state.response, state.responseBody.body, state)
        }
        guard let (recorder, transaction, finalResponse, body, snapshot) = pending else { return false }

        let tls = tlsInfo(for: transaction.request.url, from: snapshot)
        engine.store.upsert(recorder.complete(
            transaction,
            response: finalResponse,
            body: body,
            error: error,
            tls: tls,
            timing: snapshot.connection?.timing
        ))
        return !snapshot.isStopped
    }

    /// Falls back to the cached chain when no handshake happened on this load (reused connection).
    private func tlsInfo(for url: URL, from state: LoadState) -> CWTLSInfo? {
        guard url.scheme?.lowercased() == "https" else { return nil }

        let cached = state.certificates.isEmpty
            ? CWCertificateCache.key(for: url).flatMap(engine.certificates.chain(for:))
            : nil
        guard state.connection != nil || !state.certificates.isEmpty || cached != nil else { return nil }

        return CWTLSInfo(
            connection: state.connection,
            certificates: cached ?? state.certificates,
            isChainFromEarlierConnection: cached != nil,
            trustDecision: state.trustDecision
        )
    }

    func recordUnsentFailure(_ error: CWCaptureError, recorder: CWRecorder) {
        guard let transaction = recorder.begin(request, body: nil) else { return }

        engine.store.upsert(recorder.complete(transaction, response: nil, body: nil, error: error))
    }
}

// MARK: - Requests

private extension CWURLProtocol {

    /// Copy sent upstream: marked as handled (no re-interception) with the body inlined,
    /// because the original stream has already been consumed.
    static func upstreamRequest(from request: URLRequest, body: Data?) -> URLRequest? {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return nil
        }
        setProperty(true, forKey: handledKey, in: mutable)
        if let body {
            mutable.httpBody = body
        }
        return mutable as URLRequest
    }

    /// Redirect target given back to the app, with the handled marker removed so it is captured too.
    static func clientRequest(from request: URLRequest) -> URLRequest {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        removeProperty(forKey: handledKey, in: mutable)
        return mutable as URLRequest
    }
}
#endif
