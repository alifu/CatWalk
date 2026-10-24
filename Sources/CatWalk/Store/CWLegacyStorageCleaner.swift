//
//  CWLegacyStorageCleaner.swift
//  CatWalk
//

import Foundation
import os

/// Removes the disk logs written by pre-1.0 builds (`Application Support/APILogger/`).
/// CatWalk is memory-only now, so leftover plaintext captures should not linger.
enum CWLegacyStorageCleaner {

    private static let logger = Logger(subsystem: "com.catwalk", category: "storage")
    private static let legacyDirectoryName = "APILogger"

    /// Runs once per process, off the calling thread.
    static func cleanOnce() {
        _ = scheduled
    }

    /// Deletes the legacy directory when it exists.
    /// - Returns: whether something was removed.
    @discardableResult
    static func removeLegacyDirectory(in baseDirectory: URL, fileManager: FileManager = .default) -> Bool {
        let directory = baseDirectory.appendingPathComponent(legacyDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return false }

        do {
            try fileManager.removeItem(at: directory)
            logger.info("Removed legacy log directory")
            return true
        } catch {
            logger.error("Could not remove legacy log directory: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static let scheduled: Void = {
        DispatchQueue.global(qos: .utility).async {
            guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                return
            }
            removeLegacyDirectory(in: base)
        }
    }()
}
