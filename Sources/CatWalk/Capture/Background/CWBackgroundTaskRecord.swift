#if CATWALK_ENABLED
//
//  CWBackgroundTaskRecord.swift
//  CatWalk
//

import Foundation

/// What CatWalk learned about one background-session task, attached to the task itself.
final class CWBackgroundTaskRecord: NSObject, @unchecked Sendable {

    struct State {
        var metrics: CWConnectionMetrics?
        var downloadedBody: CWBody?
        var receivedBody: CWBodyAccumulator
        var uploadFile: URL?
        var isRecorded = false
    }

    /// Transaction id; the same task always maps to the same row.
    let id = UUID()
    let state: CWLocked<State>

    private init(limit: Int) {
        state = CWLocked(State(receivedBody: CWBodyAccumulator(limit: limit)))
    }

    nonisolated(unsafe) private static let key = CWRuntime.makeKey()
    private static let creation = NSLock()

    /// Get or create; creation is serialised so racing callbacks share one record.
    static func of(_ task: URLSessionTask, limit: Int) -> CWBackgroundTaskRecord {
        creation.lock()
        defer { creation.unlock() }
        if let record: CWBackgroundTaskRecord = CWRuntime.associated(task, key: key) {
            return record
        }
        let record = CWBackgroundTaskRecord(limit: limit)
        CWRuntime.associate(record, with: task, key: key)
        return record
    }

    static func existing(for task: URLSessionTask) -> CWBackgroundTaskRecord? {
        CWRuntime.associated(task, key: key)
    }
}
#endif
