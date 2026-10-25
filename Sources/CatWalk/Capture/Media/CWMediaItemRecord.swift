#if CATWALK_ENABLED
//
//  CWMediaItemRecord.swift
//  CatWalk
//

import Foundation

/// What CatWalk keeps per `AVPlayerItem`, attached to the item itself.
final class CWMediaItemRecord: NSObject, @unchecked Sendable {

    struct State {
        /// Request rows recorded so far, against `maxMediaRequestsPerItem`.
        var requestCount = 0
        var skippedCount = 0
        /// Access-log rows by URI, updated in place as the log grows.
        var playbackRowIDs: [String: UUID] = [:]
        var processedErrorCount = 0
    }

    let itemID = UUID()
    let state = CWLocked(State())

    nonisolated(unsafe) private static let key = CWRuntime.makeKey()
    private static let creation = NSLock()

    /// Get or create; creation is serialised so racing callbacks share one record.
    static func of(_ item: AnyObject) -> CWMediaItemRecord {
        creation.lock()
        defer { creation.unlock() }
        if let record: CWMediaItemRecord = CWRuntime.associated(item, key: key) {
            return record
        }
        let record = CWMediaItemRecord()
        CWRuntime.associate(record, with: item, key: key)
        return record
    }

    static func existing(for item: AnyObject) -> CWMediaItemRecord? {
        CWRuntime.associated(item, key: key)
    }
}
#endif
