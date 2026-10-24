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
        self.cw_default.insertingCatWalkProtocol()
    }

    @objc dynamic class var cw_ephemeral: URLSessionConfiguration {
        self.cw_ephemeral.insertingCatWalkProtocol()
    }

    /// Each getter call returns a fresh configuration, so this edits only that new copy.
    private func insertingCatWalkProtocol() -> URLSessionConfiguration {
        let catWalk = ObjectIdentifier(CWURLProtocol.self)
        protocolClasses = [CWURLProtocol.self] + (protocolClasses ?? []).filter { ObjectIdentifier($0) != catWalk }
        return self
    }
}
#endif
