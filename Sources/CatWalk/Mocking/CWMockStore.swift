//
//  CWMockStore.swift
//  CatWalk
//

import Foundation

/// Mock rules for the running process (memory only; rules made in code are re-registered each launch).
///
/// Lookup: `.exact` URLs are found through a dictionary in O(1) plus the rules sharing that URL;
/// the remaining rules are tried in insertion order, O(k). Exact rules always win over patterns.
final class CWMockStore: Sendable {

    fileprivate struct Entry {
        let rule: CWMockRule
        /// Compiled once when the rule is added.
        let regex: NSRegularExpression?
    }

    private struct State {
        var entries: [UUID: Entry] = [:]
        /// Insertion order of rule ids.
        var order: [UUID] = []
        /// Absolute URL → ids of `.exact` rules for it, in insertion order.
        var exactIndex: [String: [UUID]] = [:]
        var hits: [UUID: Int] = [:]
    }

    private let state = CWLocked(State())

    var rules: [CWMockRule] {
        state.withLock { state in state.order.compactMap { state.entries[$0]?.rule } }
    }

    func hitCount(for id: UUID) -> Int {
        state.withLock { $0.hits[id] ?? 0 }
    }

    /// Adds a rule, or replaces the one with the same id (keeping its position and hit count).
    /// - Throws: `CWConfigurationError.invalidMockPattern` when a `.regex` does not compile.
    func add(_ rule: CWMockRule) throws {
        let regex = try Self.compile(rule.matcher.url)
        state.withLock { state in
            if state.entries[rule.id] != nil {
                Self.unindex(rule.id, in: &state)
            } else {
                state.order.append(rule.id)
            }
            state.entries[rule.id] = Entry(rule: rule, regex: regex)
            if case let .exact(url) = rule.matcher.url {
                state.exactIndex[url, default: []].append(rule.id)
            }
        }
    }

    func setEnabled(_ isEnabled: Bool, for id: UUID) {
        state.withLock { state in
            guard let entry = state.entries[id] else { return }
            state.entries[id] = Entry(rule: entry.rule.enabled(isEnabled), regex: entry.regex)
        }
    }

    func remove(id: UUID) {
        state.withLock { state in
            guard state.entries.removeValue(forKey: id) != nil else { return }
            Self.unindex(id, in: &state)
            state.order.removeAll { $0 == id }
            state.hits.removeValue(forKey: id)
        }
    }

    func removeAll() {
        state.withLock { $0 = State() }
    }

    /// First enabled rule matching the request, counting the hit.
    func match(_ request: URLRequest) -> CWMockRule? {
        guard let url = request.url else { return nil }
        let absoluteURL = url.absoluteString
        let context = CWMockRequestContext(request: request, absoluteURL: absoluteURL)

        return state.withLock { state in
            let exact = (state.exactIndex[absoluteURL] ?? []).compactMap { state.entries[$0] }
            let patterns = state.order.compactMap { state.entries[$0] }.lazy.filter { entry in
                if case .exact = entry.rule.matcher.url { return false }
                return true
            }
            let matched = (exact + patterns).first { $0.rule.isEnabled && $0.matches(context) }
            guard let rule = matched?.rule else { return nil }

            state.hits[rule.id, default: 0] += 1
            return rule
        }
    }

    private static func compile(_ match: CWURLMatch) throws -> NSRegularExpression? {
        guard case let .regex(pattern) = match else { return nil }
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            throw CWConfigurationError.invalidMockPattern(pattern)
        }
    }

    private static func unindex(_ id: UUID, in state: inout State) {
        guard case let .exact(url)? = state.entries[id]?.rule.matcher.url else { return }
        let remaining = (state.exactIndex[url] ?? []).filter { $0 != id }
        state.exactIndex[url] = remaining.isEmpty ? nil : remaining
    }
}

// MARK: - Matching

private struct CWMockRequestContext {
    let request: URLRequest
    let absoluteURL: String
}

private extension CWMockStore.Entry {

    func matches(_ context: CWMockRequestContext) -> Bool {
        let matcher = rule.matcher
        return matchesMethod(matcher.method, of: context.request)
            && matchesURL(matcher.url, context: context)
            && matchesHeaders(matcher.requiredHeaders, of: context.request)
    }

    func matchesMethod(_ method: String?, of request: URLRequest) -> Bool {
        guard let method else { return true }
        return (request.httpMethod ?? "GET").caseInsensitiveCompare(method) == .orderedSame
    }

    func matchesURL(_ match: CWURLMatch, context: CWMockRequestContext) -> Bool {
        switch match {
        case let .exact(url):
            return context.absoluteURL == url
        case let .path(path):
            return context.request.url?.path == path
        case let .prefix(prefix):
            return context.absoluteURL.hasPrefix(prefix)
        case let .contains(text):
            return context.absoluteURL.contains(text)
        case .regex:
            let range = NSRange(context.absoluteURL.startIndex..., in: context.absoluteURL)
            return regex?.firstMatch(in: context.absoluteURL, range: range) != nil
        }
    }

    func matchesHeaders(_ required: [String: String], of request: URLRequest) -> Bool {
        required.allSatisfy { name, value in
            request.value(forHTTPHeaderField: name)?.caseInsensitiveCompare(value) == .orderedSame
        }
    }
}
