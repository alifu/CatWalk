//
//  CWTransactionStore.swift
//  CatWalk
//

import Foundation

/// In-memory transaction store. Nothing is written to disk; data dies with the process.
///
/// Phase 1 keeps it unbounded; Phase 2 swaps the storage for a capacity- and
/// byte-bounded ring buffer behind the same API.
final class CWTransactionStore: Sendable {

    private struct Storage {
        var order: [UUID] = []
        var byID: [UUID: CWTransaction] = [:]
    }

    private let storage = CWLocked(Storage())

    /// O(1) amortised: inserts new ids at the tail, replaces existing ones in place.
    func upsert(_ transaction: CWTransaction) {
        storage.withLock { storage in
            if storage.byID.updateValue(transaction, forKey: transaction.id) == nil {
                storage.order.append(transaction.id)
            }
        }
    }

    /// O(1).
    func transaction(id: UUID) -> CWTransaction? {
        storage.withLock { $0.byID[id] }
    }

    /// O(n), newest first.
    func snapshot() -> [CWTransaction] {
        storage.withLock { storage in
            storage.order.reversed().compactMap { storage.byID[$0] }
        }
    }

    var count: Int {
        storage.withLock { $0.order.count }
    }

    func removeAll() {
        storage.withLock { $0 = Storage() }
    }
}
