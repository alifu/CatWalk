#if CATWALK_ENABLED
//
//  CWTransactionStoreTests.swift
//  CatWalk
//

import Combine
import Foundation
import Testing
@testable import CatWalk

@Suite("CWTransactionStore")
struct CWTransactionStoreTests {

    private let store = CWTransactionStore()
    private let recorder = CWRecorder(configuration: .default)

    private func makeTransaction(_ path: String, bodyBytes: Int = 0) throws -> CWTransaction {
        let url = try #require(URL(string: "https://example.com/\(path)"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = bodyBytes > 0 ? Data(repeating: 1, count: bodyBytes) : nil
        return try #require(recorder.begin(request, body: body))
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

    @Test("capacity evicts the oldest and keeps the index consistent")
    func capacityEviction() throws {
        let store = CWTransactionStore(capacity: 3)
        let all = try (1...5).map { try makeTransaction("\($0)") }

        all.forEach(store.upsert)

        #expect(store.snapshot().map(\.id) == all.suffix(3).reversed().map(\.id))
        #expect(store.transaction(id: all[0].id) == nil)
        #expect(store.transaction(id: all[1].id) == nil)
        #expect(store.transaction(id: all[4].id) != nil)

        let finished = recorder.complete(all[2], response: nil, body: nil, error: nil)
        store.upsert(finished)
        #expect(store.count == 3)
        #expect(store.transaction(id: all[2].id)?.state == .completed)
    }

    @Test("byte budget evicts oldest transactions but never the newest")
    func byteBudget() throws {
        let store = CWTransactionStore(capacity: 10, maxTotalBodyBytes: 250)
        let all = try (1...4).map { try makeTransaction("\($0)", bodyBytes: 100) }

        all.forEach(store.upsert)

        #expect(store.snapshot().map(\.id) == [all[3].id, all[2].id])
        #expect(store.totalBodyBytes == 200)

        let huge = try makeTransaction("huge", bodyBytes: 1_000)
        store.upsert(huge)
        #expect(store.snapshot().map(\.id) == [huge.id])
    }

    @Test("replacing a transaction updates the byte total")
    func budgetOnReplace() throws {
        let store = CWTransactionStore()
        let pending = try makeTransaction("a", bodyBytes: 100)
        store.upsert(pending)

        let body = CWBody(capturing: Data(repeating: 2, count: 40), limit: 1_000)
        store.upsert(recorder.complete(pending, response: nil, body: body, error: nil))

        #expect(store.totalBodyBytes == 100)

        store.removeAll()
        #expect(store.totalBodyBytes == 0)
    }

    @Test("purge strips finished bodies, keeps sizes and in-flight bodies")
    func purge() throws {
        let store = CWTransactionStore()
        let inFlight = try makeTransaction("flying", bodyBytes: 10)
        let done = recorder.complete(try makeTransaction("done", bodyBytes: 20), response: nil, body: nil, error: nil)
        store.upsert(done)
        store.upsert(inFlight)

        store.purgeCompletedBodies()

        let purged = try #require(store.transaction(id: done.id))
        #expect(purged.request.body?.data.isEmpty == true)
        #expect(purged.request.body?.totalBytes == 20)
        #expect(purged.request.body?.isTruncated == true)
        #expect(store.transaction(id: inFlight.id)?.request.body?.data.count == 10)
        #expect(store.totalBodyBytes == 10)
        #expect(store.snapshot().map(\.id) == [inFlight.id, done.id])
    }

    @Test("configure keeps the newest transactions that fit")
    func configure() throws {
        let store = CWTransactionStore(capacity: 5)
        let all = try (1...4).map { try makeTransaction("\($0)") }
        all.forEach(store.upsert)

        store.configure(capacity: 2, maxTotalBodyBytes: 1_000)

        #expect(store.capacity == 2)
        #expect(store.snapshot().map(\.id) == [all[3].id, all[2].id])
        #expect(store.transaction(id: all[3].id) != nil)
    }

    @Test("publishes changes")
    func changes() throws {
        let store = CWTransactionStore(capacity: 1)
        var received: [CWStoreChange] = []
        let cancellable = store.changes.sink { received.append($0) }
        let first = try makeTransaction("a")

        store.upsert(first)
        store.removeAll()

        #expect(received == [.upserted(first.id), .cleared])
        cancellable.cancel()
    }

    @Test("update replaces a stored transaction in place and ignores evicted ones")
    func updateInPlace() throws {
        let store = CWTransactionStore(capacity: 2)
        let first = TransactionFixtures.make("GET", "https://a.test/1")
        let second = TransactionFixtures.make("GET", "https://a.test/2")
        let third = TransactionFixtures.make("GET", "https://a.test/3")
        store.upsert(first)
        store.upsert(second)
        let timing = CWTiming.mocked(startingAt: Date(), delay: 1)

        store.update(id: second.id) { $0.withConnectionDetails(tls: nil, timing: timing) }
        store.upsert(third)
        store.update(id: first.id) { $0.withConnectionDetails(tls: nil, timing: timing) }

        #expect(store.snapshot().map(\.id) == [third.id, second.id])
        #expect(store.transaction(id: second.id)?.timing == timing)
        #expect(store.transaction(id: first.id) == nil)
    }
}
#endif
