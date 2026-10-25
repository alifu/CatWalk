#if CATWALK_ENABLED
//
//  CWLocked.swift
//  CatWalk
//

import Foundation

/// Lock-protected box for state shared across threads.
///
/// `Mutex` (Synchronization) needs iOS 18, so this wraps `NSLock` for iOS 15.
/// Never call out to foreign code (e.g. a `URLProtocolClient`) inside `withLock`:
/// the lock is not recursive and a re-entrant call would deadlock.
final class CWLocked<Value>: @unchecked Sendable {

    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
#endif
