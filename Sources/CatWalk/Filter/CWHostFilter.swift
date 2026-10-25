#if CATWALK_ENABLED
//
//  CWHostFilter.swift
//  CatWalk
//

import Foundation

/// Hosts CatWalk must not capture. Immutable: edits return a new filter.
///
/// Rules (case-insensitive, trailing dot ignored):
/// - `api.example.com` matches that host only.
/// - `*.example.com` matches `example.com` and every subdomain of it.
struct CWHostFilter: Sendable, Equatable {

    static let empty = CWHostFilter(exact: [], wildcardSuffixes: [])

    private let exact: Set<String>
    private let wildcardSuffixes: Set<String>

    private init(exact: Set<String>, wildcardSuffixes: Set<String>) {
        self.exact = exact
        self.wildcardSuffixes = wildcardSuffixes
    }

    var isEmpty: Bool {
        exact.isEmpty && wildcardSuffixes.isEmpty
    }

    /// Normalised rules, sorted, for display.
    var rules: [String] {
        (exact.map { $0 } + wildcardSuffixes.map { "*." + $0 }).sorted()
    }

    /// O(L) in the number of labels: one exact lookup, then one lookup per parent suffix.
    func isIgnored(_ host: String?) -> Bool {
        guard !isEmpty, let host = Self.normalised(host) else { return false }
        if exact.contains(host) { return true }

        var suffix = Substring(host)
        while true {
            if wildcardSuffixes.contains(String(suffix)) { return true }
            guard let dot = suffix.firstIndex(of: ".") else { return false }
            suffix = suffix[suffix.index(after: dot)...]
        }
    }

    func adding(_ rule: String) throws -> CWHostFilter {
        let parsed = try Self.parse(rule)
        return CWHostFilter(
            exact: parsed.isWildcard ? exact : exact.union([parsed.host]),
            wildcardSuffixes: parsed.isWildcard ? wildcardSuffixes.union([parsed.host]) : wildcardSuffixes
        )
    }

    func removing(_ rule: String) throws -> CWHostFilter {
        let parsed = try Self.parse(rule)
        return CWHostFilter(
            exact: parsed.isWildcard ? exact : exact.subtracting([parsed.host]),
            wildcardSuffixes: parsed.isWildcard ? wildcardSuffixes.subtracting([parsed.host]) : wildcardSuffixes
        )
    }

    /// - Returns: the filter plus the rules that were rejected.
    static func build(from rules: [String]) -> (filter: CWHostFilter, rejected: [String]) {
        rules.reduce(into: (filter: CWHostFilter.empty, rejected: [String]())) { result, rule in
            do {
                result.filter = try result.filter.adding(rule)
            } catch {
                result.rejected.append(rule)
            }
        }
    }
}

// MARK: - Parsing

private extension CWHostFilter {

    static let wildcardPrefix = "*."
    static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")

    static func normalised(_ host: String?) -> String? {
        guard var host = host?.trimmingCharacters(in: .whitespaces).lowercased(), !host.isEmpty else {
            return nil
        }
        if host.hasSuffix(".") {
            host.removeLast()
        }
        return host.isEmpty ? nil : host
    }

    static func parse(_ rule: String) throws -> (host: String, isWildcard: Bool) {
        var text = rule.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.contains("://") {
            guard let host = URL(string: text)?.host else { throw CWConfigurationError.invalidHost(rule) }
            text = host
        }

        let isWildcard = text.hasPrefix(wildcardPrefix)
        if isWildcard {
            text.removeFirst(wildcardPrefix.count)
        }

        guard let host = normalised(text), isValid(host, isWildcard: isWildcard) else {
            throw CWConfigurationError.invalidHost(rule)
        }
        return (host, isWildcard)
    }

    /// Wildcards need at least two labels so `*.com` cannot silence a whole TLD.
    static func isValid(_ host: String, isWildcard: Bool) -> Bool {
        guard host.unicodeScalars.allSatisfy(allowedCharacters.contains) else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.contains(where: \.isEmpty) else { return false }
        return !isWildcard || labels.count >= 2
    }
}
#endif
