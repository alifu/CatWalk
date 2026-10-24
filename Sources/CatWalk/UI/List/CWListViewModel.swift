#if CATWALK_ENABLED
//
//  CWListViewModel.swift
//  CatWalk
//

import Combine
import Foundation

/// Feeds the transaction list: filtering and sorting run off the main thread, store bursts are throttled.
@MainActor
final class CWListViewModel: ObservableObject {

    @Published var filter = CWTransactionFilter()
    @Published private(set) var transactions: [CWTransaction] = []
    @Published private(set) var hosts: [String] = []
    @Published private(set) var totalCount = 0

    let store: CWTransactionStore
    private var cancellable: AnyCancellable?
    private let workQueue = DispatchQueue(label: "com.catwalk.list-filter", qos: .userInitiated)

    init(store: CWTransactionStore = CWCaptureEngine.shared.store) {
        self.store = store
        cancellable = Self.pipeline(store: store, filter: $filter, queue: workQueue)
            .sink { [weak self] result in
                self?.transactions = result.transactions
                self?.hosts = result.hosts
                self?.totalCount = result.totalCount
            }
    }

    private struct Result: Sendable {
        let transactions: [CWTransaction]
        let hosts: [String]
        let totalCount: Int
    }

    private nonisolated static func pipeline(
        store: CWTransactionStore,
        filter: Published<CWTransactionFilter>.Publisher,
        queue: DispatchQueue
    ) -> AnyPublisher<Result, Never> {
        let changes = store.changes.map { _ in () }.prepend(())
        return Publishers.CombineLatest(filter.debounce(for: .milliseconds(150), scheduler: DispatchQueue.main), changes)
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .receive(on: queue)
            .map { filter, _ in
                let all = store.snapshot()
                return Result(transactions: filter.apply(to: all), hosts: CWTransactionFilter.hosts(in: all), totalCount: all.count)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func hide(_ id: UUID) {
        filter.hiddenIDs.insert(id)
    }

    func clearAll() {
        store.removeAll()
        filter.hiddenIDs = []
    }

    func toggle(method: String) {
        if filter.methods.contains(method) { filter.methods.remove(method) } else { filter.methods.insert(method) }
    }

    func toggle(statusClass: CWStatusClass) {
        if filter.statusClasses.contains(statusClass) {
            filter.statusClasses.remove(statusClass)
        } else {
            filter.statusClasses.insert(statusClass)
        }
    }

    func ignore(host: String) {
        try? CatWalk.ignore(host: host)
        if filter.host == host { filter.host = nil }
    }
}
#endif
