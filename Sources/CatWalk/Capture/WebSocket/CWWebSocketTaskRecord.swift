#if CATWALK_ENABLED
//
//  CWWebSocketTaskRecord.swift
//  CatWalk
//

import Foundation

/// Where one WebSocket task stands in CatWalk, attached to the task itself.
final class CWWebSocketTaskRecord: NSObject, @unchecked Sendable {

    enum Phase {
        /// Not recorded yet (resumed while capture was off, or not resumed).
        case idle
        case open
        /// Ignored host or no URL: never recorded.
        case skipped
        case closed
    }

    struct State {
        var phase = Phase.idle
        var hasHandshake = false
    }

    /// Transaction id; the same task always maps to the same row.
    let id = UUID()
    let state = CWLocked(State())

    nonisolated(unsafe) private static let key = CWRuntime.makeKey()
    private static let creation = NSLock()

    /// Get or create; creation is serialised so racing callbacks share one record.
    static func of(_ task: AnyObject) -> CWWebSocketTaskRecord {
        creation.lock()
        defer { creation.unlock() }
        if let record: CWWebSocketTaskRecord = CWRuntime.associated(task, key: key) {
            return record
        }
        let record = CWWebSocketTaskRecord()
        CWRuntime.associate(record, with: task, key: key)
        return record
    }
}
#endif
