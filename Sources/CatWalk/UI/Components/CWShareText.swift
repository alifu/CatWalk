#if CATWALK_ENABLED
//
//  CWShareText.swift
//  CatWalk
//

import Foundation

/// Plain-text renderings of the parts of a transaction, for the share sheet.
enum CWShareText {

    static func headers(_ headers: CWHeaders) -> String? {
        guard !headers.isEmpty else { return nil }
        return headers.entries.map { "\($0.name): \($0.value)" }.joined(separator: "\n")
    }

    static func cookies(_ cookies: [CWCookie]) -> String? {
        guard !cookies.isEmpty else { return nil }
        return cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "\n")
    }

    /// The body as it was received; hex for binary payloads.
    static func body(_ body: CWBody?, mimeType: String?) -> String? {
        switch CWBodyPreview.make(for: body, mimeType: mimeType) {
        case .json, .text:
            return body.flatMap { String(data: $0.data, encoding: .utf8) }
        case let .binary(hexDump):
            return hexDump
        case .empty, .purged, .image:
            return nil
        }
    }

    /// Everything about one exchange as a single document; O(total size).
    static func all(_ transaction: CWTransaction) -> String {
        let request = transaction.request
        let response = transaction.response
        let cookies = [
            cookies(transaction.requestCookies).map { "Sent:\n\($0)" },
            cookies(transaction.responseCookies).map { "Received:\n\($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
        let sections: [(String, String?)] = [
            ("URL", request.url.absoluteString),
            ("Method", request.method),
            ("Status", status(transaction)),
            ("Timing", transaction.timing.map(timing)),
            ("Request headers", headers(request.headers)),
            ("Request body", bodyOrMark(request.body, mimeType: request.headers["Content-Type"])),
            ("Response headers", response.flatMap { headers($0.headers) }),
            ("Response body", bodyOrMark(response?.body, mimeType: response?.mimeType)),
            ("Cookies", cookies.isEmpty ? nil : cookies),
        ]
        return sections
            .map { title, text in "## \(title)\n\(text ?? emptyMark)" }
            .joined(separator: "\n\n")
    }

    static let emptyMark = "(empty)"

    private static func bodyOrMark(_ captured: CWBody?, mimeType: String?) -> String? {
        if let text = body(captured, mimeType: mimeType) { return text }
        guard let captured, captured.totalBytes > 0 else { return nil }
        return "(\(CWFormat.bytes(captured.totalBytes)) not shown as text)"
    }

    static func status(_ transaction: CWTransaction) -> String {
        var lines = ["Status: \(transaction.response.map { String($0.statusCode) } ?? transaction.statusDescription)"]
        if let error = transaction.error {
            lines.append("Error: \(error.message) (\(error.domain) \(error.code))")
        }
        return lines.joined(separator: "\n")
    }

    static func timing(_ timing: CWTiming) -> String {
        let phases: [(String, DateInterval?)] = [
            ("DNS", timing.domainLookup), ("Connect", timing.connect), ("TLS", timing.secureConnection),
            ("Send", timing.request), ("Wait", timing.waiting), ("Receive", timing.response),
            ("Total", timing.total),
        ]
        return phases
            .compactMap { name, interval in interval.map { "\(name): \(CWFormat.duration($0.duration))" } }
            .joined(separator: "\n")
    }
}
#endif
