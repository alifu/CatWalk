//
//  CWCookieParser.swift
//  CatWalk
//

import Foundation

/// Extracts cookies from request and response headers.
enum CWCookieParser {

    /// Cookies an outgoing request carries: its explicit `Cookie` header plus cookies
    /// the session adds from storage. Header cookies win on name clashes. O(n).
    static func requestCookies(
        cookieHeader: String?,
        storedCookies: [HTTPCookie]
    ) -> [CWCookie] {
        let explicit = cookieHeader.map(parseCookieHeader) ?? []
        let explicitNames = Set(explicit.map(\.name))
        let stored = storedCookies
            .filter { !explicitNames.contains($0.name) }
            .map(CWCookie.init)
        return explicit + stored
    }

    /// Parses `name=value; name2=value2`, skipping pairs without a name or `=`.
    static func parseCookieHeader(_ header: String) -> [CWCookie] {
        header
            .split(separator: ";")
            .compactMap { pair in
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }

                let name = parts[0].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }

                return CWCookie(name: name, value: parts[1].trimmingCharacters(in: .whitespaces))
            }
    }

    /// Parses every `Set-Cookie` in a response (Foundation joins repeats with commas).
    static func responseCookies(headerFields: [String: String], url: URL) -> [CWCookie] {
        HTTPCookie
            .cookies(withResponseHeaderFields: headerFields, for: url)
            .map(CWCookie.init)
    }
}
