//
//  CWRingBuffer.swift
//  CatWalk
//

/// Fixed-capacity FIFO buffer. Every append is O(1); a full buffer overwrites its oldest slot.
///
/// Elements are addressed by a monotonically increasing *sequence number*, which stays valid
/// until the element is evicted, so callers can keep a stable `id -> sequence` index.
struct CWRingBuffer<Element> {

    let capacity: Int

    private var slots: [Element?]
    private var firstSequence = 0

    private(set) var count = 0

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.slots = Array(repeating: nil, count: self.capacity)
    }

    /// Sequence the next appended element will get.
    var nextSequence: Int {
        firstSequence + count
    }

    var isFull: Bool {
        count == capacity
    }

    /// - Returns: the sequence assigned to `element`, and the element it evicted when full.
    @discardableResult
    mutating func append(_ element: Element) -> (sequence: Int, evicted: Element?) {
        let evicted = isFull ? removeFirst() : nil
        let sequence = nextSequence
        slots[sequence % capacity] = element
        count += 1
        return (sequence, evicted)
    }

    func element(at sequence: Int) -> Element? {
        contains(sequence) ? slots[sequence % capacity] : nil
    }

    /// - Returns: `false` when `sequence` is no longer (or not yet) in the buffer.
    @discardableResult
    mutating func replace(at sequence: Int, with element: Element) -> Bool {
        guard contains(sequence) else { return false }
        slots[sequence % capacity] = element
        return true
    }

    @discardableResult
    mutating func removeFirst() -> Element? {
        guard count > 0 else { return nil }
        let index = firstSequence % capacity
        let removed = slots[index]
        slots[index] = nil
        firstSequence += 1
        count -= 1
        return removed
    }

    /// O(n), newest first.
    func newestFirst() -> [Element] {
        (firstSequence..<nextSequence).reversed().compactMap { slots[$0 % capacity] }
    }

    mutating func removeAll() {
        self = CWRingBuffer(capacity: capacity)
    }

    private func contains(_ sequence: Int) -> Bool {
        sequence >= firstSequence && sequence < nextSequence
    }
}
