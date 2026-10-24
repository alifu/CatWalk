//
//  CWShakeDetector.swift
//  CatWalk
//

import ObjectiveC
import UIKit

/// Opens the inspector on a device shake by hooking `UIWindow.motionEnded(_:with:)`.
///
/// `UIWindow` inherits that method from `UIResponder`, so the hook is set on `UIWindow` itself and
/// the original implementation is called with the original selector. (Calling it under another
/// name would break UIKit, whose default implementation forwards to the next responder by `_cmd`.)
enum CWShakeDetector {

    private typealias MotionEnded = @convention(c) (AnyObject, Selector, UIEvent.EventSubtype, UIEvent?) -> Void

    /// Static initialisers run exactly once and are thread-safe.
    private static let installation: Void = {
        let selector = #selector(UIResponder.motionEnded(_:with:))
        guard let method = class_getInstanceMethod(UIWindow.self, selector) else {
            assertionFailure("CatWalk: unable to hook motionEnded")
            return
        }
        let original = unsafeBitCast(class_getMethodImplementation(UIWindow.self, selector), to: MotionEnded.self)
        let hook: @convention(block) (UIWindow, UIEvent.EventSubtype, UIEvent?) -> Void = { window, motion, event in
            original(window, selector, motion, event)
            guard motion == .motionShake else { return }
            MainActor.assumeIsolated { CWPresenter.shared.handleShake() }
        }
        class_replaceMethod(UIWindow.self, selector, imp_implementationWithBlock(hook), method_getTypeEncoding(method))
    }()

    /// Idempotent. Not reversible; whether a shake does anything is decided when it happens.
    static func install() {
        _ = installation
    }
}
