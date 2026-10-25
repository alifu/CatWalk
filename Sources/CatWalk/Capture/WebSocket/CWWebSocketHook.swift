#if CATWALK_ENABLED && !CATWALK_EXCLUDE_WEBSOCKET
//
//  CWWebSocketHook.swift
//  CatWalk
//

import Foundation
import ObjectiveC
import os

/// `URLProtocol` is never consulted for `ws`/`wss`, so CatWalk observes WebSocket tasks directly.
///
/// The task's runtime class (`__NSURLSessionWebSocketTask` today, private) gets hooks for resume,
/// send, receive, ping and cancel that call the original implementation with the original selector.
/// Swift's `async` `send`/`receive` bridge to the same Objective-C methods, so both styles are seen.
/// The class is hooked at install when it can be found by name, and otherwise when the first task
/// is created. A missing selector (a future OS change) is logged once and skipped, never a crash.
enum CWWebSocketHook {

    private static let logger = Logger(subsystem: "com.catwalk", category: "websocket")
    private static let hookedClasses = CWLocked<Set<ObjectIdentifier>>([])

    private static let installation: Void = {
        hookFactories()
        if let known = NSClassFromString("__NSURLSessionWebSocketTask") {
            hookTaskClass(known)
        }
    }()

    /// Idempotent; the hooks do nothing while capture is stopped or `captureWebSockets` is off.
    static func install() {
        _ = installation
    }

    /// By behaviour, not class: the runtime class is not a `URLSessionWebSocketTask` subclass.
    static func isWebSocketTask(_ task: URLSessionTask) -> Bool {
        CWTaskKind.isWebSocket(task)
    }

    /// Hooks the class of `task` once, e.g. a renamed class first seen through a factory.
    static func discovered(_ task: AnyObject) {
        if let type = object_getClass(task) {
            hookTaskClass(type)
        }
    }
}

// MARK: - Session factories

private extension CWWebSocketHook {

    static func hookFactories() {
        typealias OneArgument = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject
        typealias TwoArguments = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> AnyObject

        for name in ["webSocketTaskWithURL:", "webSocketTaskWithRequest:"] {
            let selector = NSSelectorFromString(name)
            hook(URLSession.self, selector) { original in
                let create = unsafeBitCast(original, to: OneArgument.self)
                let block: @convention(block) (AnyObject, AnyObject) -> AnyObject = { session, argument in
                    let task = create(session, selector, argument)
                    discovered(task)
                    return task
                }
                return block
            }
        }

        let selector = NSSelectorFromString("webSocketTaskWithURL:protocols:")
        hook(URLSession.self, selector) { original in
            let create = unsafeBitCast(original, to: TwoArguments.self)
            let block: @convention(block) (AnyObject, AnyObject, AnyObject) -> AnyObject = { session, url, protocols in
                let task = create(session, selector, url, protocols)
                discovered(task)
                return task
            }
            return block
        }
    }
}

// MARK: - Task class

private extension CWWebSocketHook {

    typealias ErrorHandler = @convention(block) (NSError?) -> Void
    typealias MessageHandler = @convention(block) (NSObject?, NSError?) -> Void

    static func hookTaskClass(_ type: AnyClass) {
        let isNew = hookedClasses.withLock { $0.insert(ObjectIdentifier(type)).inserted }
        guard isNew else { return }
        hookResume(type)
        hookSend(type)
        hookReceive(type)
        hookPing(type)
        hookCancelWithCode(type)
        hookCancel(type)
    }

    /// Installs only when `selector` exists, so the original is never `nil`.
    static func hook(_ type: AnyClass, _ selector: Selector, makeBlock: (IMP) -> Any) {
        let installed = CWRuntime.hook(type, selector) { original in
            original.map(makeBlock) ?? ({ () -> Void in } as @convention(block) () -> Void)
        }
        if !installed {
            logger.warning("WebSocket capture skips \(NSStringFromSelector(selector), privacy: .public) on \(NSStringFromClass(type), privacy: .public): not found")
        }
    }

    static func hookResume(_ type: AnyClass) {
        let selector = NSSelectorFromString("resume")
        typealias Original = @convention(c) (NSObject, Selector) -> Void
        hook(type, selector) { original in
            let resume = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (NSObject) -> Void = { task in
                CWWebSocketRecorder.didResume(task)
                resume(task, selector)
            }
            return block
        }
    }

    static func hookSend(_ type: AnyClass) {
        let selector = NSSelectorFromString("sendMessage:completionHandler:")
        typealias Original = @convention(c) (NSObject, Selector, NSObject, ErrorHandler?) -> Void
        hook(type, selector) { original in
            let send = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (NSObject, NSObject, ErrorHandler?) -> Void = { task, message, completion in
                let frameID = CWWebSocketRecorder.didSend(message, task: task)
                let observed: ErrorHandler = { error in
                    if let error, let frameID {
                        CWWebSocketRecorder.didFailToSend(frameID: frameID, error: error, task: task)
                    }
                    completion?(error)
                }
                send(task, selector, message, observed)
            }
            return block
        }
    }

    static func hookReceive(_ type: AnyClass) {
        let selector = NSSelectorFromString("receiveMessageWithCompletionHandler:")
        typealias Original = @convention(c) (NSObject, Selector, MessageHandler?) -> Void
        hook(type, selector) { original in
            let receive = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (NSObject, MessageHandler?) -> Void = { task, completion in
                let observed: MessageHandler = { message, error in
                    if let message {
                        CWWebSocketRecorder.didReceive(message, task: task)
                    } else if let error {
                        CWWebSocketRecorder.didFailToReceive(error, task: task)
                    }
                    completion?(message, error)
                }
                receive(task, selector, observed)
            }
            return block
        }
    }

    static func hookPing(_ type: AnyClass) {
        let selector = NSSelectorFromString("sendPingWithPongReceiveHandler:")
        typealias Original = @convention(c) (NSObject, Selector, ErrorHandler?) -> Void
        hook(type, selector) { original in
            let ping = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (NSObject, ErrorHandler?) -> Void = { task, completion in
                CWWebSocketRecorder.didSendPing(task: task)
                let observed: ErrorHandler = { error in
                    if error == nil {
                        CWWebSocketRecorder.didReceivePong(task: task)
                    }
                    completion?(error)
                }
                ping(task, selector, observed)
            }
            return block
        }
    }

    /// Recorded before forwarding: the original may call `cancel`, which must not close the row twice.
    static func hookCancelWithCode(_ type: AnyClass) {
        let selector = NSSelectorFromString("cancelWithCloseCode:reason:")
        typealias Original = @convention(c) (NSObject, Selector, Int, NSData?) -> Void
        hook(type, selector) { original in
            let cancel = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (NSObject, Int, NSData?) -> Void = { task, code, reason in
                CWWebSocketRecorder.didCancel(task, code: code, reason: reason as Data?)
                cancel(task, selector, code, reason)
            }
            return block
        }
    }

    static func hookCancel(_ type: AnyClass) {
        let selector = NSSelectorFromString("cancel")
        typealias Original = @convention(c) (NSObject, Selector) -> Void
        hook(type, selector) { original in
            let cancel = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (NSObject) -> Void = { task in
                CWWebSocketRecorder.didCancel(task, code: nil, reason: nil)
                cancel(task, selector)
            }
            return block
        }
    }
}
#endif
