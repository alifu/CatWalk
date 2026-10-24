//
//  CWTransactionStoreTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWTransactionStore")
struct CWTransactionStoreTests {

    private let store = CWTransactionStore()
    private let recorder = CWRecorder(configuration: .default)

    private func makeTransaction(_ path: String) throws -> CWTransaction {
        let url = try #require(URL(string: "https://example.com/\(path)"))
        return try #require(recorder.begin(URLRequest(url: url), body: nil))
    }

    @Test("snapshot returns newest first")
    func newestFirst() throws {
        let first = try makeTransaction("a")
        let second = try makeTransaction("b")

        store.upsert(first)
        store.upsert(second)

        #expect(store.snapshot().map(\.id) == [second.id, first.id])
        #expect(store.count == 2)
    }

    @Test("upsert replaces an existing transaction in place")
    func replace() throws {
        let first = try makeTransaction("a")
        let second = try makeTransaction("b")
        store.upsert(first)
        store.upsert(second)

        let finished = recorder.complete(first, response: nil, body: nil, error: nil)
        store.upsert(finished)

        #expect(store.count == 2)
        #expect(store.transaction(id: first.id)?.state == .completed)
        #expect(store.snapshot().map(\.id) == [second.id, first.id])
    }

    @Test("removeAll empties the store")
    func removeAll() throws {
        store.upsert(try makeTransaction("a"))

        store.removeAll()

        #expect(store.count == 0)
        #expect(store.snapshot().isEmpty)
    }
}
