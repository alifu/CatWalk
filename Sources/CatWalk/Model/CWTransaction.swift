#if CATWALK_ENABLED
//
//  CWTransaction.swift
//  CatWalk
//

import Foundation

/// One request/response exchange. Immutable: state changes return a new copy.
public struct CWTransaction: Sendable, Identifiable, Equatable {

    /// How CatWalk saw the exchange.
    public enum Source: Sendable, Equatable, CaseIterable {
        /// Intercepted in the app (`URLProtocol`): full capture, mockable.
        case urlSession
        /// Observed from a background session's delegate: read-only, appears when it finishes.
        case backgroundSession
        /// A `URLSessionWebSocketTask`: handshake plus every message, read-only.
        case webSocket
    }

    public enum State: Sendable, Equatable {
        case inFlight
        case completed
        case failed
        /// Answered by a `CWMockRule`; the network was not used.
        case mocked
    }

    public let id: UUID

    public let state: State

    public let request: CWHTTPRequest

    public let requestCookies: [CWCookie]

    public let startDate: Date

    public let response: CWHTTPResponse?

    public let responseCookies: [CWCookie]

    public let endDate: Date?

    public let error: CWTransactionError?

    /// `nil` for plain HTTP, and until the exchange finishes.
    public let tls: CWTLSInfo?

    public let source: Source

    /// Phase breakdown; `nil` until the system reports metrics (they can arrive after completion).
    public let timing: CWTiming?

    /// Messages of a WebSocket connection; `nil` for HTTP exchanges.
    public let webSocket: CWWebSocketLog?

    /// Lowercased "method url status", built once per state for O(1)-setup search.
    let searchKey: String

    /// Mock rules only apply to requests CatWalk intercepts itself.
    public var isMockable: Bool {
        source == .urlSession
    }

    public var isMocked: Bool {
        state == .mocked
    }

    public var duration: TimeInterval? {
        endDate.map { $0.timeIntervalSince(startDate) }
    }

    init(
        id: UUID,
        request: CWHTTPRequest,
        requestCookies: [CWCookie],
        startDate: Date
    ) {
        self.init(
            id: id,
            state: .inFlight,
            request: request,
            requestCookies: requestCookies,
            startDate: startDate,
            response: nil,
            responseCookies: [],
            endDate: nil,
            error: nil,
            tls: nil,
            timing: nil
        )
    }

    private init(
        id: UUID,
        state: State,
        request: CWHTTPRequest,
        requestCookies: [CWCookie],
        startDate: Date,
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        endDate: Date?,
        error: CWTransactionError?,
        tls: CWTLSInfo?,
        timing: CWTiming?,
        source: Source = .urlSession,
        webSocket: CWWebSocketLog? = nil
    ) {
        self.id = id
        self.state = state
        self.request = request
        self.requestCookies = requestCookies
        self.startDate = startDate
        self.response = response
        self.responseCookies = responseCookies
        self.endDate = endDate
        self.error = error
        self.tls = tls
        self.timing = timing
        self.source = source
        self.webSocket = webSocket
        self.searchKey = Self.makeSearchKey(request: request, response: response)
    }
}

// MARK: - Transitions

extension CWTransaction {

    func completed(
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        tls: CWTLSInfo? = nil,
        timing: CWTiming? = nil,
        at date: Date
    ) -> CWTransaction {
        finished(.completed, response: response, responseCookies: responseCookies, error: nil, tls: tls, timing: timing, at: date)
    }

    func failed(
        error: CWTransactionError,
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        tls: CWTLSInfo? = nil,
        timing: CWTiming? = nil,
        at date: Date
    ) -> CWTransaction {
        finished(.failed, response: response, responseCookies: responseCookies, error: error, tls: tls, timing: timing, at: date)
    }

    /// Same exchange, flagged as answered by a mock rule, with the mock's own timing.
    func markedMocked(timing: CWTiming? = nil) -> CWTransaction {
        copy(state: .mocked, timing: .some(timing ?? self.timing))
    }

    /// Adds details the system reports after the exchange was recorded (metrics of a redirect hop).
    func withConnectionDetails(tls: CWTLSInfo?, timing: CWTiming?) -> CWTransaction {
        copy(tls: .some(tls ?? self.tls), timing: .some(timing ?? self.timing))
    }

    func from(_ source: Source) -> CWTransaction {
        copy(source: source)
    }

    /// The handshake request of a WebSocket, before any message.
    func asWebSocket() -> CWTransaction {
        copy(source: .webSocket, webSocket: .some(CWWebSocketLog()))
    }

    /// Handshake response of an open WebSocket; the exchange stays in flight.
    func withHandshake(response: CWHTTPResponse?, cookies: [CWCookie]) -> CWTransaction {
        copy(response: .some(response), responseCookies: cookies)
    }

    /// Changes the message log; HTTP transactions are returned unchanged.
    func updatingWebSocket(_ transform: (CWWebSocketLog) -> CWWebSocketLog) -> CWTransaction {
        guard let webSocket else { return self }
        return copy(webSocket: .some(transform(webSocket)))
    }

    private func finished(
        _ state: State,
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        error: CWTransactionError?,
        tls: CWTLSInfo?,
        timing: CWTiming?,
        at date: Date
    ) -> CWTransaction {
        CWTransaction(
            id: id,
            state: state,
            request: request,
            requestCookies: requestCookies,
            startDate: startDate,
            response: response,
            responseCookies: responseCookies,
            endDate: date,
            error: error,
            tls: tls,
            timing: timing,
            source: source,
            webSocket: webSocket
        )
    }

    private func copy(
        state: State? = nil,
        request: CWHTTPRequest? = nil,
        response: CWHTTPResponse?? = nil,
        responseCookies: [CWCookie]? = nil,
        tls: CWTLSInfo?? = nil,
        timing: CWTiming?? = nil,
        source: Source? = nil,
        webSocket: CWWebSocketLog?? = nil
    ) -> CWTransaction {
        CWTransaction(
            id: id,
            state: state ?? self.state,
            request: request ?? self.request,
            requestCookies: requestCookies,
            startDate: startDate,
            response: response ?? self.response,
            responseCookies: responseCookies ?? self.responseCookies,
            endDate: endDate,
            error: error,
            tls: tls ?? self.tls,
            timing: timing ?? self.timing,
            source: source ?? self.source,
            webSocket: webSocket ?? self.webSocket
        )
    }
}

// MARK: - Memory

extension CWTransaction {

    /// Captured bytes held by this transaction (request + response bodies, WebSocket payloads).
    var storedBodyBytes: Int {
        (request.body?.data.count ?? 0) + (response?.body?.data.count ?? 0) + (webSocket?.storedBytes ?? 0)
    }

    func strippingBodies() -> CWTransaction {
        copy(
            request: request.strippingBody(),
            response: .some(response?.strippingBody()),
            webSocket: .some(webSocket?.strippingData())
        )
    }
}

// MARK: - Search

private extension CWTransaction {

    static func makeSearchKey(request: CWHTTPRequest, response: CWHTTPResponse?) -> String {
        let status = response.map { String($0.statusCode) } ?? ""
        return "\(request.method) \(request.url.absoluteString) \(status)".lowercased()
    }
}
#endif
