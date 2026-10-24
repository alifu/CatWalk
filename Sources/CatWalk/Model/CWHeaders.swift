//
//  CWHeaders.swift
//  CatWalk
//

import Foundation

/// A single HTTP header as received.
public struct CWHeader: Sendable, Hashable {

    public let name: String

    public let value: String
}

/// HTTP headers sorted for display, with O(1) case-insensitive lookup.
public struct CWHeaders: Sendable, Equatable {

    /// Entries sorted by name, ignoring case.
    public let entries: [CWHeader]

    /// Lowercased name → index into `entries`.
    private let indexByName: [String: Int]

    /// O(h log h) once at capture time, h = header count.
    public init(_ fields: [String: String]) {
        let sorted = fields
            .map { (key: $0.key.lowercased(), header: CWHeader(name: $0.key, value: $0.value)) }
            .sorted { $0.key < $1.key }
            .map(\.header)
        self.init(entries: sorted)
    }

    private init(entries: [CWHeader]) {
        self.entries = entries
        self.indexByName = Dictionary(
            entries.enumerated().map { ($1.name.lowercased(), $0) },
            uniquingKeysWith: { _, last in last }
        )
    }

    /// O(1) case-insensitive value lookup.
    public subscript(name: String) -> String? {
        indexByName[name.lowercased()].map { entries[$0].value }
    }

    public var isEmpty: Bool {
        entries.isEmpty
    }

    /// Returns a copy whose listed headers (lowercased names) carry `CWRedaction.placeholder`.
    func redacting(_ lowercasedNames: Set<String>) -> CWHeaders {
        guard !lowercasedNames.isEmpty else { return self }

        let redacted = entries.map { header in
            lowercasedNames.contains(header.name.lowercased())
                ? CWHeader(name: header.name, value: CWRedaction.placeholder)
                : header
        }
        return CWHeaders(entries: redacted)
    }
}
