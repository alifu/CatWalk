#if CATWALK_ENABLED
//
//  CWRuntime.swift
//  CatWalk
//

import Foundation
import ObjectiveC

/// Objective-C runtime helpers for the observation hooks.
enum CWRuntime {

    /// Replaces `selector` on `type` itself with the block from `makeBlock`, which receives the
    /// implementation that ran before (the class's own, or the inherited one; `nil` when missing).
    /// The original must be called with the **original selector**: UIKit/Foundation defaults forward by `_cmd`.
    ///
    /// - Parameter fallbackTypes: encoding used when no class in the hierarchy implements the selector.
    /// - Returns: `false` when the selector is missing and `fallbackTypes` is `nil` (nothing installed).
    @discardableResult
    static func hook(
        _ type: AnyClass,
        _ selector: Selector,
        fallbackTypes: UnsafePointer<CChar>? = nil,
        makeBlock: (IMP?) -> Any
    ) -> Bool {
        let method = class_getInstanceMethod(type, selector)
        guard let types = method.flatMap(method_getTypeEncoding) ?? fallbackTypes else { return false }

        let original = method.map(method_getImplementation)
        class_replaceMethod(type, selector, imp_implementationWithBlock(makeBlock(original)), types)
        return true
    }

    /// Encoding of an optional instance method of an Objective-C protocol.
    static func types(of selector: Selector, inProtocol name: String) -> UnsafePointer<CChar>? {
        guard let proto = objc_getProtocol(name) else { return nil }
        return protocol_getMethodDescription(proto, selector, false, true).types.map { UnsafePointer($0) }
    }

    /// Value attached to `object` for its lifetime.
    static func associated<Value: AnyObject>(_ object: AnyObject, key: UnsafeRawPointer) -> Value? {
        objc_getAssociatedObject(object, key) as? Value
    }

    static func associate(_ value: AnyObject?, with object: AnyObject, key: UnsafeRawPointer) {
        objc_setAssociatedObject(object, key, value, .OBJC_ASSOCIATION_RETAIN)
    }

    /// Stable addresses for associated-object keys.
    static func makeKey() -> UnsafeRawPointer {
        UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))
    }
}
#endif
