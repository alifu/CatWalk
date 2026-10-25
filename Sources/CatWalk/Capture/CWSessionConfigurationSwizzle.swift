#if CATWALK_ENABLED
//
//  CWSessionConfigurationSwizzle.swift
//  CatWalk
//

import Foundation

/// Prepends `CWURLProtocol` to `URLSessionConfiguration.default` / `.ephemeral`,
/// so sessions the app creates itself (e.g. Alamofire) are captured too.
/// `URLProtocol.registerClass` alone only reaches `URLSession.shared`.
enum CWSessionConfigurationSwizzle {

    /// Static initialisers run exactly once and are thread-safe.
    private static let installation: Void = {
        exchange(
            #selector(getter: URLSessionConfiguration.`default`),
            with: #selector(getter: URLSessionConfiguration.cw_default)
        )
        exchange(
            #selector(getter: URLSessionConfiguration.ephemeral),
            with: #selector(getter: URLSessionConfiguration.cw_ephemeral)
        )
    }()

    /// Idempotent. Not reversible; capture is gated by `CWURLProtocol.canInit` instead.
    static func install() {
        _ = installation
    }

    /// `true` until `start` applies `interceptCustomSessions`, so sessions created before
    /// `start` (after the load-time bootstrap) are injected too.
    private static let injection = CWLocked(true)

    static var isInjecting: Bool {
        injection.withLock { $0 }
    }

    static func setInjecting(_ isInjecting: Bool) {
        injection.withLock { $0 = isInjecting }
    }

    private static func exchange(_ original: Selector, with replacement: Selector) {
        let type: AnyClass = URLSessionConfiguration.self
        guard
            let originalMethod = class_getClassMethod(type, original),
            let replacementMethod = class_getClassMethod(type, replacement)
        else {
            assertionFailure("CatWalk: unable to swizzle \(original)")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}

extension URLSessionConfiguration {

    /// After the exchange, `cw_default` runs the original `default` getter.
    @objc dynamic class var cw_default: URLSessionConfiguration {
        let configuration = self.cw_default
        return CWSessionConfigurationSwizzle.isInjecting ? configuration.insertingCatWalkProtocol() : configuration
    }

    @objc dynamic class var cw_ephemeral: URLSessionConfiguration {
        let configuration = self.cw_ephemeral
        return CWSessionConfigurationSwizzle.isInjecting ? configuration.insertingCatWalkProtocol() : configuration
    }

    /// Each getter call returns a fresh configuration, so this edits only that new copy.
    private func insertingCatWalkProtocol() -> URLSessionConfiguration {
        let catWalk = ObjectIdentifier(CWURLProtocol.self)
        protocolClasses = [CWURLProtocol.self] + (protocolClasses ?? []).filter { ObjectIdentifier($0) != catWalk }
        return self
    }
}
#endif
