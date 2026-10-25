#if CATWALK_ENABLED
//
//  CWTransactionStore.swift
//  CatWalk
//

import Combine
import Foundation

/// In-memory transaction store. Nothing is written to disk; data dies with the process.
///
/// Bounded twice: by transaction count (ring buffer, oldest evicted first) and by total
/// captured body bytes (`CWMemoryBudget`).
final class CWTransactionStore: @unchecked Sendable {

    static let defaultCapacity = CWConfiguration.defaultMaxTransactions
    static let defaultMaxTotalBodyBytes = CWConfiguration.defaultMaxTotalBodyBytes

    fileprivate struct Storage {
        var ring: CWRingBuffer<CWTransaction>
        var sequenceByID: [UUID: Int] = [:]
        var budget: CWMemoryBudget
    }

    private let storage: CWLocked<Storage>
    private let subject = PassthroughSubject<CWStoreChange, Never>()

    init(
        capacity: Int = CWTransactionStore.defaultCapacity,
        maxTotalBodyBytes: Int = CWTransactionStore.defaultMaxTotalBodyBytes
    ) {
        storage = CWLocked(Storage(
            ring: CWRingBuffer(capacity: capacity),
            budget: CWMemoryBudget(maxTotalBodyBytes: maxTotalBodyBytes)
        ))
    }

    var changes: AnyPublisher<CWStoreChange, Never> {
        subject.eraseToAnyPublisher()
    }

    // MARK: - Reads

    /// O(1).
    func transaction(id: UUID) -> CWTransaction? {
        storage.withLock { storage in
            storage.sequenceByID[id].flatMap { storage.ring.element(at: $0) }
        }
    }

    /// O(n), newest first.
    func snapshot() -> [CWTransaction] {
        storage.withLock { $0.ring.newestFirst() }
    }

    var count: Int {
        storage.withLock { $0.ring.count }
    }

    var capacity: Int {
        storage.withLock { $0.ring.capacity }
    }

    var totalBodyBytes: Int {
        storage.withLock { $0.budget.totalBodyBytes }
    }

    // MARK: - Writes

    /// O(1) amortised, plus one O(1) eviction per transaction over the limits.
    func upsert(_ transaction: CWTransaction) {
        let trimmed = storage.withLock { storage -> Bool in
            insert(transaction, into: &storage)
            return trim(&storage)
        }
        subject.send(.upserted(transaction.id))
        if trimmed {
            subject.send(.trimmed)
        }
    }

    /// Replaces a stored transaction with `transform(old)`; does nothing if it was evicted. O(1).
    func update(id: UUID, _ transform: (CWTransaction) -> CWTransaction) {
        let updated = storage.withLock { storage -> Bool in
            guard let sequence = storage.sequenceByID[id], let old = storage.ring.element(at: sequence) else {
                return false
            }
            insert(transform(old), into: &storage)
            return true
        }
        if updated {
            subject.send(.upserted(id))
        }
    }

    /// Applies new limits, keeping the newest transactions that still fit.
    func configure(capacity: Int, maxTotalBodyBytes: Int) {
        storage.withLock { storage in
            let kept = storage.ring.newestFirst().reversed()
            storage = Storage(
                ring: CWRingBuffer(capacity: capacity),
                budget: CWMemoryBudget(maxTotalBodyBytes: maxTotalBodyBytes)
            )
            kept.forEach { insert($0, into: &storage) }
            trim(&storage)
        }
        subject.send(.trimmed)
    }

    /// Drops captured bytes of finished transactions (sizes are kept), e.g. on a memory warning.
    func purgeCompletedBodies() {
        storage.withLock { storage in
            let purged = storage.ring.newestFirst().reversed().map { transaction in
                transaction.state == .inFlight ? transaction : transaction.strippingBodies()
            }
            storage = Storage(
                ring: CWRingBuffer(capacity: storage.ring.capacity),
                budget: CWMemoryBudget(maxTotalBodyBytes: storage.budget.maxTotalBodyBytes)
            )
            purged.forEach { insert($0, into: &storage) }
        }
        subject.send(.trimmed)
    }

    func removeAll() {
        storage.withLock { storage in
            storage.ring.removeAll()
            storage.sequenceByID.removeAll()
            storage.budget.reset()
        }
        subject.send(.cleared)
    }
}

// MARK: - Storage mutation (call under the lock)

private extension CWTransactionStore {

    func insert(_ transaction: CWTransaction, into storage: inout Storage) {
        if let sequence = storage.sequenceByID[transaction.id],
           let old = storage.ring.element(at: sequence) {
            storage.ring.replace(at: sequence, with: transaction)
            storage.budget.remove(old.storedBodyBytes)
            storage.budget.add(transaction.storedBodyBytes)
            return
        }

        let (sequence, evicted) = storage.ring.append(transaction)
        storage.sequenceByID[transaction.id] = sequence
        storage.budget.add(transaction.storedBodyBytes)
        if let evicted {
            forget(evicted, in: &storage)
        }
    }

    /// Evicts oldest transactions while over the byte budget, always keeping the newest.
    /// - Returns: whether anything was evicted.
    @discardableResult
    func trim(_ storage: inout Storage) -> Bool {
        var didTrim = false
        while storage.budget.isOverBudget, storage.ring.count > 1, let oldest = storage.ring.removeFirst() {
            forget(oldest, in: &storage)
            didTrim = true
        }
        return didTrim
    }

    func forget(_ transaction: CWTransaction, in storage: inout Storage) {
        storage.sequenceByID[transaction.id] = nil
        storage.budget.remove(transaction.storedBodyBytes)
    }
}
#endif
