#if CATWALK_ENABLED
//
//  CWJSONTreeView.swift
//  CatWalk
//

import SwiftUI

/// Collapsible JSON. Containers show at most `childLimit` children to keep huge arrays responsive.
struct CWJSONTreeView: View {

    let node: CWJSONNode

    var body: some View {
        ScrollView(.horizontal) {
            LazyVStack(alignment: .leading, spacing: 4) {
                CWJSONNodeView(key: nil, node: node, depth: 0)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct CWJSONNodeView: View {

    static let childLimit = 200

    let key: String?
    let node: CWJSONNode
    let depth: Int

    @State private var isExpanded: Bool

    init(key: String?, node: CWJSONNode, depth: Int) {
        self.key = key
        self.node = node
        self.depth = depth
        _isExpanded = State(initialValue: depth < 1)
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
        HStack(spacing: 4) {
            if let key {
                Text(key + ":").foregroundColor(.purple)
            }
            Text(node.summary).foregroundColor(color)
        }
        .font(.system(.footnote, design: .monospaced))
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var children: some View {
        switch node {
        case let .object(members):
            ForEach(Array(members.prefix(Self.childLimit).enumerated()), id: \.offset) { _, member in
                CWJSONNodeView(key: member.key, node: member.node, depth: depth + 1)
            }
            overflow(members.count)
        case let .array(items):
            ForEach(Array(items.prefix(Self.childLimit).enumerated()), id: \.offset) { index, item in
                CWJSONNodeView(key: String(index), node: item, depth: depth + 1)
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
