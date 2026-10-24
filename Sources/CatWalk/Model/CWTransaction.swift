//
//  CWTransaction.swift
//  CatWalk
//

import Foundation

/// One request/response exchange. Immutable: state changes return a new copy.
public struct CWTransaction: Sendable, Identifiable, Equatable {

    public enum State: Sendable, Equatable {
        case inFlight
        case completed
        case failed
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

    /// Lowercased "method url status", built once per state for O(1)-setup search.
    let searchKey: String

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
            error: nil
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
        error: CWTransactionError?
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
        self.searchKey = Self.makeSearchKey(request: request, response: response)
    }
}

// MARK: - Transitions

extension CWTransaction {

    func completed(
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        at date: Date
    ) -> CWTransaction {
        finished(.completed, response: response, responseCookies: responseCookies, error: nil, at: date)
    }

    func failed(
        error: CWTransactionError,
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        at date: Date
    ) -> CWTransaction {
        finished(.failed, response: response, responseCookies: responseCookies, error: error, at: date)
    }

    private func finished(
        _ state: State,
        response: CWHTTPResponse?,
        responseCookies: [CWCookie],
        error: CWTransactionError?,
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
            error: error
        )
    }
}

// MARK: - Memory

extension CWTransaction {

    /// Captured body bytes held by this transaction (request + response).
    var storedBodyBytes: Int {
        (request.body?.data.count ?? 0) + (response?.body?.data.count ?? 0)
    }

    func strippingBodies() -> CWTransaction {
        CWTransaction(
            id: id,
            state: state,
            request: request.strippingBody(),
            requestCookies: requestCookies,
            startDate: startDate,
            response: response?.strippingBody(),
            responseCookies: responseCookies,
            endDate: endDate,
            error: error
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
