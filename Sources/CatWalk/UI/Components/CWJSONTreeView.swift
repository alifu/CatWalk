#if CATWALK_ENABLED
//
//  CWJSONTreeView.swift
//  CatWalk
//

import SwiftUI

/// Collapsible JSON. Containers show at most `childLimit` children to keep huge arrays responsive.
/// A non-empty `query` shows only the matching keys and values, fully expanded.
struct CWJSONTreeView: View {

    private static let debounce: UInt64 = 250_000_000

    private struct SearchResult {
        let query: String
        let node: CWJSONNode?
    }

    let node: CWJSONNode
    let query: String

    @State private var result: SearchResult?

    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Group {
            if needle.isEmpty {
                tree(node, expandsAll: false)
            } else if let result, result.query == needle {
                if let match = result.node {
                    tree(match, expandsAll: true).id(needle)
                } else {
                    Text("No matches").font(.footnote).foregroundColor(.secondary)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task(id: needle) { await search() }
    }

    private func tree(_ root: CWJSONNode, expandsAll: Bool) -> some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            CWJSONNodeView(key: nil, node: root, depth: 0, expandsAll: expandsAll)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Debounced, cancelled by the next keystroke, and run off the main thread.
    private func search() async {
        guard !needle.isEmpty else { return }
        let target = needle
        let root = node
        do { try await Task.sleep(nanoseconds: Self.debounce) } catch { return }
        let match = await Task.detached(priority: .userInitiated) { root.filtered(matching: target) }.value
        guard !Task.isCancelled else { return }
        result = SearchResult(query: target, node: match)
    }
}

private struct CWJSONNodeView: View {

    static let childLimit = 200

    let key: String?
    let node: CWJSONNode
    let depth: Int
    let expandsAll: Bool

    @State private var isExpanded: Bool

    init(key: String?, node: CWJSONNode, depth: Int, expandsAll: Bool) {
        self.key = key
        self.node = node
        self.depth = depth
        self.expandsAll = expandsAll
        _isExpanded = State(initialValue: expandsAll || depth < 1)
    }

    var body: some View {
        if node.childCount != nil {
            DisclosureGroup(isExpanded: $isExpanded) {
                children
            } label: {
                label
            }
        } else {
            label
        }
    }

    private var label: some View {
        (keyText + Text(node.summary).foregroundColor(color))
            .font(.system(.footnote, design: .monospaced))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var keyText: Text {
        key.map { Text($0 + ": ").foregroundColor(.purple) } ?? Text("")
    }

    @ViewBuilder
    private var children: some View {
        switch node {
        case let .object(members):
            ForEach(Array(members.prefix(Self.childLimit).enumerated()), id: \.offset) { _, member in
                CWJSONNodeView(key: member.key, node: member.node, depth: depth + 1, expandsAll: expandsAll)
            }
            overflow(members.count)
        case let .array(items):
            ForEach(Array(items.prefix(Self.childLimit).enumerated()), id: \.offset) { index, item in
                CWJSONNodeView(key: String(index), node: item, depth: depth + 1, expandsAll: expandsAll)
            }
            overflow(items.count)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func overflow(_ count: Int) -> some View {
        if count > Self.childLimit {
            Text("… \(count - Self.childLimit) more").font(.caption).foregroundColor(.secondary)
        }
    }

    private var color: Color {
        switch node {
        case .string: .green
        case .number: .blue
        case .bool, .null: .orange
        default: .secondary
        }
    }
}
#endif
