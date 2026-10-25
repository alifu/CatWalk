#if CATWALK_ENABLED
//
//  CWListViewModelTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWListViewModel", .serialized)
@MainActor
struct CWListViewModelTests {

    private func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    @Test("publishes store changes, filters off-main, hides rows and clears")
    func pipeline() async {
        let store = CWTransactionStore()
        let viewModel = CWListViewModel(store: store)
        let get = TransactionFixtures.make("GET", "https://a.test/one")
        let post = TransactionFixtures.make("POST", "https://b.test/two")
        store.upsert(get)
        store.upsert(post)

        #expect(await waitUntil { viewModel.transactions.count == 2 })
        #expect(viewModel.hosts == ["a.test", "b.test"])

        viewModel.toggle(method: "POST")
        #expect(await waitUntil { viewModel.transactions.map(\.id) == [post.id] })
        #expect(viewModel.totalCount == 2)

        viewModel.toggle(method: "POST")
        viewModel.hide(get.id)
        #expect(await waitUntil { viewModel.transactions.map(\.id) == [post.id] })

        viewModel.clearAll()
        #expect(await waitUntil { viewModel.transactions.isEmpty && viewModel.totalCount == 0 })
    }
}
#endif
