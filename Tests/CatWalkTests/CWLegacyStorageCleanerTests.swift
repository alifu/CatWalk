#if CATWALK_ENABLED
//
//  CWLegacyStorageCleanerTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWLegacyStorageCleaner")
struct CWLegacyStorageCleanerTests {

    @Test("removes the APILogger directory and its contents")
    func removes() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let legacy = base.appendingPathComponent("APILogger")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("secret".utf8).write(to: legacy.appendingPathComponent("logs.bin"))
        defer { try? FileManager.default.removeItem(at: base) }

        #expect(CWLegacyStorageCleaner.removeLegacyDirectory(in: base))
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test("does nothing when there is no legacy directory")
    func absent() {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        #expect(!CWLegacyStorageCleaner.removeLegacyDirectory(in: base))
    }
}
#endif
