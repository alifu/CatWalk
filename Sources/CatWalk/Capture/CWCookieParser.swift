#if CATWALK_ENABLED
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
    /// Cookies Foundation rejects (e.g. a mismatched `Domain`) are recovered from the raw header
    /// so they are never silently dropped.
    static func responseCookies(headerFields: [String: String], url: URL) -> [CWCookie] {
        let parsed = HTTPCookie
            .cookies(withResponseHeaderFields: headerFields, for: url)
            .map(CWCookie.init)
        guard let raw = headerFields.first(where: { $0.key.lowercased() == "set-cookie" })?.value else {
            return parsed
        }

        let parsedNames = Set(parsed.map(\.name))
        let recovered = splitSetCookie(raw)
            .compactMap(parseSetCookie)
            .filter { !parsedNames.contains($0.name) }
        return parsed + recovered
    }

    /// Splits a comma-joined `Set-Cookie` value, ignoring commas inside `Expires=Wed, 21 Oct ...`.
    static func splitSetCookie(_ header: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var insideExpires = false
        for character in header {
            if character == "," && !insideExpires {
                parts.append(current)
                current = ""
                continue
            }
            current.append(character)
            if character == "=" && current.lowercased().hasSuffix("expires=") { insideExpires = true }
            if character == ";" { insideExpires = false }
        }
        parts.append(current)
        return parts
    }

    private static func parseSetCookie(_ text: String) -> CWCookie? {
        let attributes = text.split(separator: ";", omittingEmptySubsequences: true)
        guard let first = attributes.first,
              let cookie = parseCookieHeader(String(first)).first else { return nil }

        func attribute(_ name: String) -> String? {
            attributes.dropFirst().compactMap { item -> String? in
                let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair[0].trimmingCharacters(in: .whitespaces).lowercased() == name else { return nil }
                return pair.count == 2 ? pair[1].trimmingCharacters(in: .whitespaces) : ""
            }.first
        }

        return CWCookie(
            name: cookie.name,
            value: cookie.value,
            domain: attribute("domain"),
            path: attribute("path"),
            isSecure: attribute("secure") != nil,
            isHTTPOnly: attribute("httponly") != nil,
            sameSite: attribute("samesite")
        )
    }
}
#endif
