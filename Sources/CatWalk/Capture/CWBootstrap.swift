#if CATWALK_ENABLED
//
//  CWBootstrap.swift
//  CatWalk
//

import CatWalkBootstrap
import Foundation

/// Load-time installation of `CWSessionConfigurationSwizzle` (see `CatWalkBootstrap.c`).
enum CWBootstrap {

    /// Info.plist key; `NO` leaves session configurations untouched until `CatWalk.start`.
    static let earlyInstallKey = "CatWalkEarlyInstall"

    static var isEarlyInstallEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: earlyInstallKey) as? Bool) ?? true
    }

    /// Whether the constructor ran; calling it also keeps the bootstrap object linked.
    static var didRunAtLoad: Bool {
        catwalk_bootstrap_did_run() != 0
    }
}

/// Called by the C constructor before `main`. Must not depend on anything `start` sets up.
@usableFromInline
@_cdecl("catwalk_bootstrap")
func catWalkBootstrap() {
    guard CWBootstrap.isEarlyInstallEnabled else { return }
    CWSessionConfigurationSwizzle.install()
    CWBackgroundSessionHook.install()
}
#endif
