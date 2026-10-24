//
//  CWSessionBridge.swift
//  CatWalk
//

import Foundation

/// Receives upstream events for one intercepted load.
protocol CWSessionBridgeClient: AnyObject, Sendable {

    func bridgeDidReceive(_ response: URLResponse)

    func bridgeDidReceive(_ data: Data)

    func bridgeWillRedirect(to request: URLRequest, response: HTTPURLResponse)

    func bridgeDidComplete(with error: (any Error)?)
}

/// One shared `URLSession` that performs every intercepted request upstream.
///
/// Replaces the old session-per-request design: connections are reused and
/// delegate callbacks (needed for redirects, and TLS/metrics in Phase 3) are available.
final class CWSessionBridge: Sendable {

    private let session: URLSession
    private let delegate: CWSessionDelegate

    /// - Parameter protocolClasses: extra upstream protocols (tests inject a stub network).
    init(protocolClasses: [AnyClass] = []) {
        let catWalk = ObjectIdentifier(CWURLProtocol.self)
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = protocolClasses
            + (configuration.protocolClasses ?? []).filter { ObjectIdentifier($0) != catWalk }

        let queue = OperationQueue()
        queue.name = "com.catwalk.session-bridge"
        queue.maxConcurrentOperationCount = 1

        let delegate = CWSessionDelegate()
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
    }

    /// Creates a task routed to `client`. The caller resumes it.
    func makeTask(for request: URLRequest, client: any CWSessionBridgeClient) -> URLSessionDataTask {
        let task = session.dataTask(with: request)
        delegate.register(client, for: task)
        return task
    }

    /// Lets in-flight tasks finish, then releases the session and its delegate.
    func invalidate() {
        session.finishTasksAndInvalidate()
    }
}

/// Routes session callbacks to the owning client by task id (O(1) lookup).
private final class CWSessionDelegate: NSObject, URLSessionDataDelegate, Sendable {

    private let clients = CWLocked<[Int: any CWSessionBridgeClient]>([:])

    func register(_ client: any CWSessionBridgeClient, for task: URLSessionTask) {
        clients.withLock { $0[task.taskIdentifier] = client }
    }

    private func client(for task: URLSessionTask) -> (any CWSessionBridgeClient)? {
        clients.withLock { $0[task.taskIdentifier] }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        client(for: dataTask)?.bridgeDidReceive(response)
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        client(for: dataTask)?.bridgeDidReceive(data)
    }

    /// The app's own session decides whether to follow, so the upstream hop stops here
    /// and the client starts a fresh (separately captured) load for the target.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        client(for: task)?.bridgeWillRedirect(to: request, response: response)
        task.cancel()
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        let client = clients.withLock { $0.removeValue(forKey: task.taskIdentifier) }
        client?.bridgeDidComplete(with: error)
    }
}
