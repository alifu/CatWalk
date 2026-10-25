#if CATWALK_ENABLED
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

    @Test("a large body round-trips through a file that is deleted with the body")
    func largeBodyLivesOnDisk() throws {
        let payload = Data(repeating: 7, count: CWBody.diskThreshold + 1)
        let before = files()
        var body: CWBody? = CWBody(capturing: payload, limit: 1 << 20)
        let created = files().subtracting(before)

        #expect(created.count == 1)
        #expect(body?.data == payload)
        #expect(body?.storedBytes == payload.count)
        #expect(body?.strippingData().storedBytes == payload.count)

        body = nil
        #expect(files().isDisjoint(with: created))
    }

    @Test("a small body stays in memory")
    func smallBodyStaysInMemory() {
        let before = files()
        let body = CWBody(capturing: Data(repeating: 1, count: 10), limit: 100)

        #expect(files() == before)
        #expect(body.strippingData().storedBytes == 0)
    }

    @Test("a body whose file vanished reads as empty")
    func missingFile() {
        let before = files()
        let body = CWBody(capturing: Data(repeating: 1, count: CWBody.diskThreshold), limit: 1 << 20)
        files().subtracting(before).forEach { try? FileManager.default.removeItem(atPath: $0) }

        #expect(body.data.isEmpty)
    }

    /// Other tests write bodies too, so compare sets of paths rather than counts.
    private func files() -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: CWBodyFile.directory.path)) ?? []
        return Set(names.map { CWBodyFile.directory.appendingPathComponent($0).path })
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
#endif
