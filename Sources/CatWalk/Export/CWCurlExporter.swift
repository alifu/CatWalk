#if CATWALK_ENABLED
//
//  CWCurlExporter.swift
//  CatWalk
//

import Foundation

/// Renders a captured request as a `curl` command.
enum CWCurlExporter {

    static func command(for transaction: CWTransaction) -> String {
        let request = transaction.request
        var parts = ["curl"]
        if request.method.uppercased() != "GET" {
            parts.append("-X \(request.method)")
        }
        parts.append(quote(request.url.absoluteString))
        parts += request.headers.entries.map { "-H \(quote("\($0.name): \($0.value)"))" }
        if let cookieHeader = storedCookieHeader(for: transaction) {
            parts.append("-H \(quote(cookieHeader))")
        }

        if let body = request.body, !body.isTruncated, !body.data.isEmpty {
            if let text = String(data: body.data, encoding: .utf8) {
                parts.append("--data-raw \(quote(text))")
            } else {
                parts.append("# binary body of \(body.totalBytes) bytes omitted")
            }
        } else if let body = request.body, body.totalBytes > 0 {
            parts.append("# body not fully captured (\(body.totalBytes) bytes) omitted")
        }
        return parts.joined(separator: " ")
    }

    /// `Cookie:` line for cookies the session added from storage, which are absent from the
    /// request headers. `nil` when a `Cookie` header was already captured or nothing is shown.
    private static func storedCookieHeader(for transaction: CWTransaction) -> String? {
        guard transaction.request.headers["Cookie"] == nil else { return nil }

        let pairs = transaction.requestCookies
            .filter { $0.value != CWRedaction.placeholder }
            .map { "\($0.name)=\($0.value)" }
        return pairs.isEmpty ? nil : "Cookie: " + pairs.joined(separator: "; ")
    }

    /// POSIX single-quoting.
    private static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
#endif
