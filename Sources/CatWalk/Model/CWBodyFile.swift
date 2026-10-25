#if CATWALK_ENABLED
//
//  CWBodyFile.swift
//  CatWalk
//

import Foundation
import os

/// One captured body in a temporary file, deleted when the last reference goes away.
final class CWBodyFile: Sendable {

    private static let logger = Logger(subsystem: "com.catwalk", category: "storage")

    /// Everything CatWalk writes lives here, so it can be wiped as a whole.
    static let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CatWalk", isDirectory: true)

    /// When this process first used body files; anything older in `directory` is from an earlier run.
    private static let launchDate = Date()

    private let url: URL

    /// - Returns: `nil` when the file cannot be written; the caller then keeps the bytes in memory.
    init?(writing data: Data) {
        _ = Self.launchDate
        let url = Self.directory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Could not write a body: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        self.url = url
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func read() -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            Self.logger.error("Could not read a body: \(error.localizedDescription, privacy: .public)")
            return Data()
        }
    }

    /// Deletes files left by an earlier run of the app. Files written by this run are kept, so it is safe to call repeatedly.
    static func removeStaleFiles() {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.creationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        for file in files {
            let created = (try? file.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
            if created < launchDate { try? fileManager.removeItem(at: file) }
        }
    }
}
#endif
