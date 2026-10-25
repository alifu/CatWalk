#if CATWALK_ENABLED
//
//  CWTransactionFilterTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWTransactionFilter")
struct CWTransactionFilterTests {

    private let ok = TransactionFixtures.make("GET", "https://api.test/products", status: 200)
    private let created = TransactionFixtures.make("POST", "https://api.test/orders", status: 201)
    private let missing = TransactionFixtures.make("GET", "https://cdn.test/logo.png", status: 404)
    private let broken = TransactionFixtures.make("GET", "https://api.test/down", status: nil, error: .timedOut)
    private let pending = TransactionFixtures.make("GET", "https://api.test/slow", status: nil)

    private var all: [CWTransaction] { [ok, created, missing, broken, pending] }

    @Test("an empty filter keeps everything in order and is inactive")
    func emptyFilter() {
        let filter = CWTransactionFilter()

        #expect(filter.apply(to: all).map(\.id) == all.map(\.id))
        #expect(!filter.isActive)
    }

    @Test("search is case-insensitive over method, URL and status")
    func search() {
        #expect(CWTransactionFilter(searchText: "  PRODUCTS ").apply(to: all).map(\.id) == [ok.id])
        #expect(CWTransactionFilter(searchText: "post").apply(to: all).map(\.id) == [created.id])
        #expect(CWTransactionFilter(searchText: "404").apply(to: all).map(\.id) == [missing.id])
    }

    @Test("status classes: 2xx, 4xx and transport errors; in-flight rows only show without a status filter")
    func statusClasses() {
        #expect(CWTransactionFilter(statusClasses: [.success]).apply(to: all).map(\.id) == [ok.id, created.id])
        #expect(CWTransactionFilter(statusClasses: [.clientError, .failed]).apply(to: all).map(\.id) == [missing.id, broken.id])
        #expect(CWStatusClass(pending) == nil)
    }

    @Test("method, host and hidden rows combine")
    func combined() {
        let filter = CWTransactionFilter(methods: ["GET"], host: "api.test", hiddenIDs: [ok.id])

        #expect(filter.apply(to: all).map(\.id) == [broken.id, pending.id])
        #expect(filter.isActive)
    }

    @Test("mocked only keeps mocked transactions")
    func mockedOnly() {
        let mocked = ok.markedMocked()

        #expect(CWTransactionFilter(mockedOnly: true).apply(to: [ok, mocked]).map(\.state) == [.mocked])
    }

    @Test("source filter keeps only that source; background rows are not mockable")
    func sourceFilter() {
        let background = ok.from(.backgroundSession)
        var filter = CWTransactionFilter()
        filter.source = .backgroundSession

        #expect(filter.apply(to: [ok, background]).map(\.source) == [.backgroundSession])
        #expect(filter.isActive)
        #expect(ok.isMockable && !background.isMockable)
    }

    @Test("hosts are unique, lowercased and sorted")
    func hosts() {
        #expect(CWTransactionFilter.hosts(in: all) == ["api.test", "cdn.test"])
    }

    @Test("clearing criteria keeps hidden rows hidden")
    func clearing() {
        let cleared = CWTransactionFilter(searchText: "x", mockedOnly: true, hiddenIDs: [ok.id]).clearingCriteria()

        #expect(!cleared.isActive)
        #expect(cleared.hiddenIDs == [ok.id])
    }
}

private extension CWTransactionFilter {
    init(
        searchText: String = "", methods: Set<String> = [], statusClasses: Set<CWStatusClass> = [],
        mockedOnly: Bool = false, host: String? = nil, hiddenIDs: Set<UUID> = []
    ) {
        self.init()
        self.searchText = searchText
        self.methods = methods
        self.statusClasses = statusClasses
        self.mockedOnly = mockedOnly
        self.host = host
        self.hiddenIDs = hiddenIDs
    }
}
#endif
