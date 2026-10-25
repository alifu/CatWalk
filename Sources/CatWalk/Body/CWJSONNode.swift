#if CATWALK_ENABLED
//
//  CWJSONNode.swift
//  CatWalk
//

import Foundation

/// Parsed JSON for the tree view. Object members are sorted by key.
indirect enum CWJSONNode: Equatable, Sendable {

    struct Member: Equatable, Sendable {
        let key: String
        let node: CWJSONNode
    }

    case object([Member])
    case array([CWJSONNode])
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    init?(data: Data) {
        guard let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        self.init(value)
    }

    private init(_ value: Any) {
        switch value {
        case let dictionary as [String: Any]:
            self = .object(dictionary.keys.sorted().map { Member(key: $0, node: CWJSONNode(dictionary[$0] ?? NSNull())) })
        case let array as [Any]:
            self = .array(array.map(CWJSONNode.init))
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            self = CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.stringValue)
        default:
            self = .null
        }
    }

    /// The subtree holding every key or scalar value that contains `needle` (case-insensitive),
    /// or `nil` when nothing matches. One pass over the nodes: O(total characters).
    /// A matching key keeps its whole subtree; filtered arrays become objects keyed by the original index.
    func filtered(matching needle: String) -> CWJSONNode? {
        switch self {
        case let .object(members):
            let kept = members.compactMap { member in
                Self.matches(member.key, needle)
                    ? member
                    : member.node.filtered(matching: needle).map { Member(key: member.key, node: $0) }
            }
            return kept.isEmpty ? nil : .object(kept)
        case let .array(items):
            let kept = items.enumerated().compactMap { index, item in
                item.filtered(matching: needle).map { Member(key: String(index), node: $0) }
            }
            return kept.isEmpty ? nil : .object(kept)
        case let .string(text), let .number(text):
            return Self.matches(text, needle) ? self : nil
        case let .bool(flag):
            return Self.matches(String(flag), needle) ? self : nil
        case .null:
            return Self.matches("null", needle) ? self : nil
        }
    }

    private static func matches(_ text: String, _ needle: String) -> Bool {
        text.range(of: needle, options: [.caseInsensitive, .literal]) != nil
    }

    /// Number of direct children for containers, `nil` for scalars.
    var childCount: Int? {
        switch self {
        case let .object(members): members.count
        case let .array(items): items.count
        default: nil
        }
    }

    var summary: String {
        switch self {
        case let .object(members): "{\(members.count)}"
        case let .array(items): "[\(items.count)]"
        case let .string(text): "\"\(text)\""
        case let .number(text): text
        case let .bool(flag): String(flag)
        case .null: "null"
        }
    }
}
#endif
