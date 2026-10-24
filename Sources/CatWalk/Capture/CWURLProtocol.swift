//
//  CWURLProtocol.swift
//  CatWalk
//

import Foundation

/// Intercepts HTTP(S) loads, forwards them through `CWSessionBridge` and records them.
///
/// Not main-actor isolated: the URL loading system calls it on its own threads.
/// Mutable state lives in a lock; client callbacks are always made outside the lock.
final class CWURLProtocol: URLProtocol, CWSessionBridgeClient, @unchecked Sendable {

    private static let handledKey = "com.catwalk.handled"
    private static let supportedSchemes: Set<String> = ["http", "https"]

    private struct LoadState {
        var recorder: CWRecorder?
        var transaction: CWTransaction?
        var response: URLResponse?
        var responseBody = CWBodyAccumulator(limit: 0)
        var task: URLSessionDataTask?
        var isStopped = false
        var isFinished = false
    }

    private let state = CWLocked(LoadState())
    private let engine = CWCaptureEngine.shared

    // MARK: - URLProtocol

    /// O(1): running flag, scheme set lookup, handled marker.
    override class func canInit(with request: URLRequest) -> Bool {
        guard
            CWCaptureEngine.shared.isRunning,
            let scheme = request.url?.scheme?.lowercased(),
            supportedSchemes.contains(scheme)
        else {
            return false
        }
        return property(forKey: handledKey, in: request) == nil
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
        let task = state.withLock { state in
            state.isStopped = true
            return state.task
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

    func bridgeDidComplete(with error: (any Error)?) {
        guard recordCompletion(response: nil, error: error) else { return }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

// MARK: - Recording

private extension CWURLProtocol {

    /// Stores the finished transaction exactly once.
    /// - Returns: `true` when the client should be told about the outcome.
    func recordCompletion(response: URLResponse?, error: (any Error)?) -> Bool {
        let pending = state.withLock { state -> (CWRecorder, CWTransaction, URLResponse?, CWBody?, Bool)? in
            guard !state.isFinished, let recorder = state.recorder, let transaction = state.transaction else {
                return nil
            }
            state.isFinished = true
            return (recorder, transaction, response ?? state.response, state.responseBody.body, state.isStopped)
        }
        guard let (recorder, transaction, finalResponse, body, isStopped) = pending else { return false }

        engine.store.upsert(recorder.complete(transaction, response: finalResponse, body: body, error: error))
        return !isStopped
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
