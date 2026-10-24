//
//  CWRecorder.swift
//  CatWalk
//

import Foundation

/// Turns Foundation request/response values into `CWTransaction`s.
/// Pure apart from reading cookie storage; applies body caps and redaction.
struct CWRecorder: Sendable {

    let configuration: CWConfiguration

    /// Lowercased once so per-header checks are O(1).
    private let redactedHeaders: Set<String>

    init(configuration: CWConfiguration) {
        self.configuration = configuration
        self.redactedHeaders = Set(configuration.redactedHeaders.map { $0.lowercased() })
    }

    /// Returns `nil` only when the request has no URL.
    func begin(
        _ request: URLRequest,
        body: Data?,
        id: UUID = UUID(),
        at date: Date = Date(),
        cookieStorage: HTTPCookieStorage = .shared
    ) -> CWTransaction? {
        guard let url = request.url else { return nil }

        let headers = CWHeaders(request.allHTTPHeaderFields ?? [:])
        let storedCookies = request.httpShouldHandleCookies
            ? cookieStorage.cookies(for: url) ?? []
            : []
        let cookies = CWCookieParser.requestCookies(
            cookieHeader: headers["Cookie"],
            storedCookies: storedCookies
        )

        let httpRequest = CWHTTPRequest(
            method: request.httpMethod ?? "GET",
            url: url,
            headers: headers.redacting(redactedHeaders),
            body: body.map { CWBody(capturing: $0, limit: configuration.maxBodyBytes) }
        )

        return CWTransaction(
            id: id,
            request: httpRequest,
            requestCookies: redact(cookies, header: "cookie"),
            startDate: date
        )
    }

    func complete(
        _ transaction: CWTransaction,
        response: URLResponse?,
        body: CWBody?,
        error: (any Error)?,
        tls: CWTLSInfo? = nil,
        at date: Date = Date()
    ) -> CWTransaction {
        let http = response as? HTTPURLResponse
        let fields = http.map(Self.headerFields) ?? [:]

        let httpResponse = http.map {
            CWHTTPResponse(
                statusCode: $0.statusCode,
                headers: CWHeaders(fields).redacting(redactedHeaders),
                body: body,
                mimeType: $0.mimeType
            )
        }
        let cookies = http.map {
            CWCookieParser.responseCookies(headerFields: fields, url: $0.url ?? transaction.request.url)
        } ?? []
        let responseCookies = redact(cookies, header: "set-cookie")

        if let error {
            return transaction.failed(
                error: CWTransactionError(error),
                response: httpResponse,
                responseCookies: responseCookies,
                tls: tls,
                at: date
            )
        }
        return transaction.completed(
            response: httpResponse,
            responseCookies: responseCookies,
            tls: tls,
            at: date
        )
    }
}

private extension CWRecorder {

    func redact(_ cookies: [CWCookie], header: String) -> [CWCookie] {
        redactedHeaders.contains(header) ? cookies.map { $0.redactingValue() } : cookies
    }

    static func headerFields(of response: HTTPURLResponse) -> [String: String] {
        Dictionary(
            response.allHeaderFields.map { (String(describing: $0.key), String(describing: $0.value)) },
            uniquingKeysWith: { _, last in last }
        )
    }
}
