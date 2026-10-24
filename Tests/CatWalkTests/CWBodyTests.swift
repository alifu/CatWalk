//
//  CWBodyTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWBody & CWBodyAccumulator")
struct CWBodyTests {

    @Test("keeps the whole body when under the limit")
    func underLimit() {
        let body = CWBody(capturing: Data(repeating: 1, count: 10), limit: 100)

        #expect(body.data.count == 10)
        #expect(body.totalBytes == 10)
        #expect(!body.isTruncated)
    }

    @Test("truncates to the limit but remembers the full size")
    func overLimit() {
        let body = CWBody(capturing: Data(repeating: 1, count: 150), limit: 100)

        #expect(body.data.count == 100)
        #expect(body.totalBytes == 150)
        #expect(body.isTruncated)
    }

    @Test("zero limit captures no bytes")
    func zeroLimit() {
        let body = CWBody(capturing: Data(repeating: 1, count: 5), limit: 0)

        #expect(body.data.isEmpty)
        #expect(body.totalBytes == 5)
        #expect(body.isTruncated)
    }

    @Test("accumulator caps captured bytes across chunks")
    func accumulatorCapsChunks() {
        var accumulator = CWBodyAccumulator(limit: 5)

        accumulator.append(Data([1, 2, 3]))
        accumulator.append(Data([4, 5, 6, 7]))

        let body = accumulator.body
        #expect(body?.data == Data([1, 2, 3, 4, 5]))
        #expect(body?.totalBytes == 7)
    }

    @Test("accumulator without data yields no body")
    func accumulatorEmpty() {
        let accumulator = CWBodyAccumulator(limit: 5)

        #expect(accumulator.body == nil)
    }
}
