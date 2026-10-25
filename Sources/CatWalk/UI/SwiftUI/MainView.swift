#if CATWALK_ENABLED
//
//  MainView.swift
//  CatWalk
//

import SwiftUI

/// Inspector root: the filtered request list with toolbar actions for mocks, settings and export.
struct MainView: View {

    var onDismiss: () -> Void

    @StateObject private var viewModel = CWListViewModel()
    @State private var shareItem: CWShareItem?
    @State private var isConfirmingClear = false
    @State private var mockDraft: CWMockDraftItem?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CWFilterBar(viewModel: viewModel).padding(.vertical, 8)
                list
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.filter.searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar { toolbar }
            .sheet(item: $shareItem) { CWShareSheet(items: $0.items) }
            .sheet(item: $mockDraft) { CWMockEditorView(draft: $0.draft) }
            .confirmationDialog("Clear all captured requests?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Clear all", role: .destructive) { viewModel.clearAll() }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var list: some View {
        List {
            ForEach(viewModel.transactions) { transaction in
                NavigationLink(destination: CWDetailView(transactionID: transaction.id, store: viewModel.store)) {
                    CWTransactionRow(transaction: transaction)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { viewModel.hide(transaction.id) } label: { Label("Delete", systemImage: "trash") }
                    Button { viewModel.ignore(host: transaction.request.url.host ?? "") } label: {
                        Label("Ignore host", systemImage: "eye.slash")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .leading) {
                    if transaction.isMockable {
                        Button { mockDraft = CWMockDraftItem(CWMockDraft(from: transaction)) } label: {
                            Label("Mock", systemImage: "theatermasks")
                        }
                        .tint(.purple)
                    }
                }
                .contextMenu { contextMenu(for: transaction) }
            }
        }
        .listStyle(.plain)
        .refreshable { viewModel.filter = viewModel.filter }
        .overlay { emptyState }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.transactions.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "network").font(.largeTitle)
                Text(viewModel.filter.isActive ? "No requests match the filters" : "No requests yet").font(.headline)
                if viewModel.filter.isActive {
                    Button("Clear filters") { viewModel.filter = viewModel.filter.clearingCriteria() }
                }
            }
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func contextMenu(for transaction: CWTransaction) -> some View {
        Button { UIPasteboard.general.string = transaction.request.url.absoluteString } label: {
            Label("Copy URL", systemImage: "doc.on.doc")
        }
        Button { UIPasteboard.general.string = CWCurlExporter.command(for: transaction) } label: {
            Label("Copy as cURL", systemImage: "terminal")
        }
        if transaction.isMockable {
            Button { mockDraft = CWMockDraftItem(CWMockDraft(from: transaction)) } label: {
                Label("Mock this response", systemImage: "theatermasks")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                CWIcon.swiftUIImage.resizable().frame(width: 22, height: 22).accessibilityHidden(true)
                Text("CatWalk").font(.headline)
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Button { onDismiss() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Close")
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            NavigationLink(destination: CWMockListView()) { Image(systemName: "theatermasks") }
                .accessibilityLabel("Mocks")
            NavigationLink(destination: CWSettingsView(store: viewModel.store)) { Image(systemName: "gearshape") }
                .accessibilityLabel("Settings")
            Menu {
                Button { shareItem = CWShareItem.har(for: viewModel.transactions) } label: {
                    Label("Share HAR", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.transactions.isEmpty)
                Button(role: .destructive) { isConfirmingClear = true } label: { Label("Clear all", systemImage: "trash") }
                    .disabled(viewModel.totalCount == 0)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }
}

#if DEBUG
#Preview {
    MainView(onDismiss: {})
}
#endif
#endif
