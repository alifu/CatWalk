#if CATWALK_ENABLED
//
//  CWWebViewRecorder.swift
//  CatWalk
//

import Foundation

/// Turns `CWWebViewEvent`s into transactions (source `.webView`).
enum CWWebViewRecorder {

    /// Script request ids still waiting for their end, at most `maxPending` (oldest dropped).
    static let maxPending = 1000

    private static let pending = CWLocked(CWPendingRequests(limit: maxPending))

    static func record(_ event: CWWebViewEvent, engine: CWCaptureEngine = .shared) {
        switch event {
        case let .start(start):
            begin(start, engine: engine)
        case let .end(end):
            finish(end.id, engine: engine, at: end.date) { recorder, transaction in
                let response = HTTPURLResponse(
                    url: transaction.request.url, statusCode: end.status, httpVersion: "HTTP/1.1", headerFields: end.headers
                )
                return recorder.complete(transaction, response: response, body: end.body, error: nil, at: end.date)
            }
        case let .failure(id, message, date):
            finish(id, engine: engine, at: date) { recorder, transaction in
                let error = NSError(domain: errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                return recorder.complete(transaction, response: nil, body: nil, error: error, at: date)
            }
        }
    }

    static let errorDomain = "CatWalk.WebView"

    /// Starts only while capturing; ends of started requests are recorded even after `stop`.
    private static func begin(_ start: CWWebViewEvent.Start, engine: CWCaptureEngine) {
        guard engine.isRunning, !engine.isIgnored(host: start.url.host) else { return }
        var request = URLRequest(url: start.url)
        request.httpMethod = start.method
        // The web view's cookies live in WKHTTPCookieStore, not HTTPCookieStorage: don't show the app's.
        request.httpShouldHandleCookies = false
        start.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        guard let begun = engine.recorder.begin(request, capturedBody: start.body, at: start.date) else { return }

        pending.withLock { $0.insert(begun.id, for: start.id) }
        engine.store.upsert(begun.from(.webView))
    }

    private static func finish(
        _ scriptID: String,
        engine: CWCaptureEngine,
        at date: Date,
        _ transform: @escaping (CWRecorder, CWTransaction) -> CWTransaction
    ) {
        guard let id = pending.withLock({ $0.remove(scriptID) }) else { return }
        let recorder = engine.recorder
        engine.store.update(id: id) { transform(recorder, $0) }
    }
}

/// Script id → transaction id, bounded so pages that never finish requests can't grow it.
struct CWPendingRequests {

    let limit: Int
    private var ids: [String: UUID] = [:]
    private var order: [String] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    var count: Int {
        ids.count
    }

    /// O(1) amortised; O(limit) when the oldest entry is dropped.
    mutating func insert(_ id: UUID, for key: String) {
        if ids.updateValue(id, forKey: key) == nil {
            order.append(key)
        }
        while ids.count > limit, !order.isEmpty {
            ids[order.removeFirst()] = nil
        }
    }

    /// O(1) for the id; the order entry is cleaned up lazily.
    mutating func remove(_ key: String) -> UUID? {
        let id = ids.removeValue(forKey: key)
        if order.count > limit * 2 {
            order.removeAll { ids[$0] == nil }
        }
        return id
    }
}
#endif
