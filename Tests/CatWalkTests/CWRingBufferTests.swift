//
//  CWRingBufferTests.swift
//  CatWalk
//

import Testing
@testable import CatWalk

@Suite("CWRingBuffer")
struct CWRingBufferTests {

    @Test("append evicts the oldest element once full")
    func wrapAround() {
        var buffer = CWRingBuffer<Int>(capacity: 3)

        let evictions = (1...5).map { buffer.append($0).evicted }

        #expect(evictions == [nil, nil, nil, 1, 2])
        #expect(buffer.newestFirst() == [5, 4, 3])
        #expect(buffer.count == 3)
    }

    @Test("sequences stay valid until evicted")
    func sequences() {
        var buffer = CWRingBuffer<String>(capacity: 2)
        let a = buffer.append("a").sequence
        let b = buffer.append("b").sequence
        let c = buffer.append("c").sequence

        let replacedEvicted = buffer.replace(at: a, with: "x")
        let replacedLive = buffer.replace(at: b, with: "B")

        #expect(buffer.element(at: a) == nil)
        #expect(buffer.element(at: b) == "B")
        #expect(buffer.element(at: c) == "c")
        #expect(!replacedEvicted)
        #expect(replacedLive)
        #expect(buffer.newestFirst() == ["c", "B"])
    }

    @Test("removeFirst and removeAll")
    func removal() {
        var buffer = CWRingBuffer<Int>(capacity: 3)
        [1, 2, 3].forEach { buffer.append($0) }

        let removed = buffer.removeFirst()
        #expect(removed == 1)
        #expect(buffer.newestFirst() == [3, 2])

        buffer.removeAll()
        let afterClear = buffer.removeFirst()
        #expect(buffer.count == 0)
        #expect(afterClear == nil)
        #expect(buffer.capacity == 3)
    }

    @Test("capacity is at least one")
    func minimumCapacity() {
        #expect(CWRingBuffer<Int>(capacity: 0).capacity == 1)
    }
}
