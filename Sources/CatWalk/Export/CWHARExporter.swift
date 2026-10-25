#if CATWALK_ENABLED
//
//  CWHARExporter.swift
//  CatWalk
//

import Foundation

/// Renders transactions as a HAR 1.2 archive that browsers and proxies can open.
enum CWHARExporter {

    static func data(for transactions: [CWTransaction]) throws -> Data {
        let log: [String: Any] = [
            "version": "1.2",
            "creator": ["name": "CatWalk", "version": "1.0"],
            "entries": transactions.map(entry),
        ]
        return try JSONSerialization.data(withJSONObject: ["log": log], options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    private static func entry(_ transaction: CWTransaction) -> [String: Any] {
        let elapsedMilliseconds = (transaction.duration ?? 0) * 1000
        return [
            "startedDateTime": transaction.startDate.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
            "time": elapsedMilliseconds,
            "request": request(transaction),
            "response": response(transaction),
            "cache": [String: Any](),
            "timings": timings(transaction.timing, elapsedMilliseconds: elapsedMilliseconds),
        ]
    }

    /// HAR uses -1 for phases that did not happen; `connect` includes `ssl`.
    private static func timings(_ timing: CWTiming?, elapsedMilliseconds: Double) -> [String: Any] {
        guard let timing else { return ["send": 0, "wait": elapsedMilliseconds, "receive": 0] }

        func milliseconds(_ interval: DateInterval?) -> Double {
            interval.map { $0.duration * 1000 } ?? -1
        }
        return [
            "blocked": -1,
            "dns": milliseconds(timing.domainLookup),
            "connect": milliseconds(timing.connect),
            "ssl": milliseconds(timing.secureConnection),
            "send": max(0, milliseconds(timing.request)),
            "wait": max(0, milliseconds(timing.waiting)),
            "receive": max(0, milliseconds(timing.response)),
        ]
    }

    private static func request(_ transaction: CWTransaction) -> [String: Any] {
        let request = transaction.request
        let query = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var result: [String: Any] = [
            "method": request.method,
            "url": request.url.absoluteString,
            "httpVersion": "HTTP/1.1",
            "headers": request.headers.entries.map { ["name": $0.name, "value": $0.value] },
            "queryString": query.map { ["name": $0.name, "value": $0.value ?? ""] },
            "cookies": transaction.requestCookies.map { ["name": $0.name, "value": $0.value] },
            "headersSize": -1,
            "bodySize": request.body?.totalBytes ?? 0,
        ]
        if let body = request.body, let text = String(data: body.data, encoding: .utf8) {
            result["postData"] = ["mimeType": request.headers["Content-Type"] ?? "", "text": text]
        }
        return result
    }

    private static func response(_ transaction: CWTransaction) -> [String: Any] {
        guard let response = transaction.response else {
            return [
                "status": 0, "statusText": transaction.error?.message ?? "", "httpVersion": "HTTP/1.1",
                "headers": [Any](), "cookies": [Any](), "redirectURL": "", "headersSize": -1, "bodySize": -1,
                "content": ["size": 0, "mimeType": ""],
            ]
        }
        return [
            "status": response.statusCode,
            "statusText": HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
            "httpVersion": "HTTP/1.1",
            "headers": response.headers.entries.map { ["name": $0.name, "value": $0.value] },
            "cookies": transaction.responseCookies.map { ["name": $0.name, "value": $0.value] },
            "content": content(of: response),
            "redirectURL": response.headers["Location"] ?? "",
            "headersSize": -1,
            "bodySize": response.body?.totalBytes ?? 0,
        ]
    }

    private static func content(of response: CWHTTPResponse) -> [String: Any] {
        var content: [String: Any] = [
            "size": response.body?.totalBytes ?? 0,
            "mimeType": response.mimeType ?? "",
        ]
        guard let body = response.body, !body.data.isEmpty else { return content }

        if let text = String(data: body.data, encoding: .utf8) {
            content["text"] = text
        } else {
            content["text"] = body.data.base64EncodedString()
            content["encoding"] = "base64"
        }
        return content
    }
}
#endif
