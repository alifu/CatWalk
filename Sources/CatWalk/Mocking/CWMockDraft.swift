//
//  CWMockDraft.swift
//  CatWalk
//

import Foundation

/// Editable text form of a `CWMockRule`, used by the mock editor.
struct CWMockDraft: Equatable {

    enum Kind: String, CaseIterable, Identifiable {
        case exact = "Exact URL", path = "Path", prefix = "Prefix", contains = "Contains", regex = "Regex"
        var id: String { rawValue }
    }

    enum ValidationError: Error, Equatable {
        case emptyPattern
        case invalidStatus
        case invalidHeader(String)
    }

    /// Empty means any method.
    var method = ""
    var kind = Kind.exact
    var pattern = ""
    var status = "200"
    /// One `Name: value` per line.
    var headersText = ""
    var body = ""
    var delay = 0.0
    var id = UUID()

    init() {}

    /// Pre-filled to replay what `transaction` received.
    init(from transaction: CWTransaction) {
        method = transaction.request.method
        pattern = transaction.request.url.absoluteString
        guard let response = transaction.response else { return }

        status = String(response.statusCode)
        headersText = response.headers.entries
            .filter { !Self.transportHeaders.contains($0.name.lowercased()) && $0.value != CWRedaction.placeholder }
            .map { "\($0.name): \($0.value)" }
            .joined(separator: "\n")
        body = response.body.flatMap { String(data: $0.data, encoding: .utf8) } ?? ""
    }

    init(from rule: CWMockRule) {
        id = rule.id
        method = rule.matcher.method ?? ""
        (kind, pattern) = Self.split(rule.matcher.url)
        status = String(rule.response.status)
        headersText = rule.response.headers.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        body = String(data: rule.response.body, encoding: .utf8) ?? ""
        delay = rule.response.delay
    }

    func rule(isEnabled: Bool = true) throws -> CWMockRule {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { throw ValidationError.emptyPattern }
        guard let code = Int(status.trimmingCharacters(in: .whitespaces)), (100..<600).contains(code) else {
            throw ValidationError.invalidStatus
        }
        let trimmedMethod = method.trimmingCharacters(in: .whitespaces)
        return CWMockRule(
            id: id,
            isEnabled: isEnabled,
            matcher: CWMockMatcher(
                method: trimmedMethod.isEmpty ? nil : trimmedMethod.uppercased(),
                url: Self.match(kind, trimmedPattern)
            ),
            response: CWMockResponse(status: code, headers: try parsedHeaders(), body: Data(body.utf8), delay: delay)
        )
    }

    private func parsedHeaders() throws -> [String: String] {
        var headers: [String: String] = [:]
        for line in headersText.split(whereSeparator: \.isNewline) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw ValidationError.invalidHeader(String(line)) }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { throw ValidationError.invalidHeader(String(line)) }
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return headers
    }

    /// Headers describing the original transfer, not content worth replaying.
    private static let transportHeaders: Set<String> = ["content-length", "content-encoding", "transfer-encoding", "connection"]

    private static func match(_ kind: Kind, _ pattern: String) -> CWURLMatch {
        switch kind {
        case .exact: .exact(pattern)
        case .path: .path(pattern)
        case .prefix: .prefix(pattern)
        case .contains: .contains(pattern)
        case .regex: .regex(pattern)
        }
    }

    private static func split(_ match: CWURLMatch) -> (Kind, String) {
        switch match {
        case let .exact(value): (.exact, value)
        case let .path(value): (.path, value)
        case let .prefix(value): (.prefix, value)
        case let .contains(value): (.contains, value)
        case let .regex(value): (.regex, value)
        }
    }
}

/// A draft to present in a sheet.
struct CWMockDraftItem: Identifiable {
    let id = UUID()
    let draft: CWMockDraft

    init(_ draft: CWMockDraft) {
        self.draft = draft
    }
}
