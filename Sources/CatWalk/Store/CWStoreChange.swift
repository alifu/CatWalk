#if CATWALK_ENABLED
//
//  CWStoreChange.swift
//  CatWalk
//

import Foundation

/// What changed in the store; lets the UI refresh without diffing snapshots.
enum CWStoreChange: Sendable, Equatable {
    case upserted(UUID)
    /// Old transactions were evicted or their bodies purged to stay within limits.
    case trimmed
    case cleared
}
#endif
