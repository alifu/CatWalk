#if CATWALK_ENABLED
//
//  CWMockListView.swift
//  CatWalk
//

import SwiftUI

/// Mock manager: enable, edit and delete rules.
struct CWMockListView: View {

    @State private var rules = CatWalk.mocks
    @State private var editing: CWMockDraftItem?

    var body: some View {
        List {
            ForEach(rules) { rule in
                HStack {
                    Button { editing = CWMockDraftItem(CWMockDraft(from: rule)) } label: { row(rule) }
                        .buttonStyle(.plain)
                    Toggle("Enabled", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { CatWalk.setMock(id: rule.id, enabled: $0); reload() }
                    ))
                    .labelsHidden()
                }
            }
            .onDelete { offsets in
                offsets.map { rules[$0].id }.forEach(CatWalk.removeMock)
                reload()
            }
        }
        .navigationTitle("Mocks")
        .overlay { if rules.isEmpty { Text("No mock rules").foregroundColor(.secondary) } }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { editing = CWMockDraftItem(CWMockDraft()) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add mock")
            }
        }
        .sheet(item: $editing, onDismiss: reload) { CWMockEditorView(draft: $0.draft) }
        .onAppear(perform: reload)
    }

    private func row(_ rule: CWMockRule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(rule.matcher.method ?? "ANY") · \(rule.response.error == nil ? String(rule.response.status) : "error")")
                .font(.subheadline.weight(.semibold))
            Text(description(of: rule.matcher.url)).font(.footnote).foregroundColor(.secondary).lineLimit(2)
            Text("\(CatWalk.mockHitCount(id: rule.id)) hits").font(.caption2).foregroundColor(.secondary)
        }
    }

    private func description(of match: CWURLMatch) -> String {
        switch match {
        case let .exact(value): value
        case let .path(value): "path \(value)"
        case let .prefix(value): "starts with \(value)"
        case let .contains(value): "contains \(value)"
        case let .regex(value): "regex \(value)"
        }
    }

    private func reload() {
        rules = CatWalk.mocks
    }
}
#endif
