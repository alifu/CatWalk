#if CATWALK_ENABLED
//
//  CWFormat.swift
//  CatWalk
//

import Foundation

/// Display strings shared by the inspector screens.
enum CWFormat {

    static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.2f s", seconds)
    }
}
#endif
