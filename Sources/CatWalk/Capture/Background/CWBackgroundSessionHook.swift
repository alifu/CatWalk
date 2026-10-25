#if CATWALK_ENABLED
//
//  CWBackgroundSessionHook.swift
//  CatWalk
//

import Foundation
import ObjectiveC

/// Background sessions never consult `URLProtocol`, so CatWalk observes them through their delegate.
///
/// 1. `+[NSURLSession sessionWithConfiguration:delegate:delegateQueue:]` marks background sessions.
/// 2. The delegate's **class** gets observation hooks that call the original implementation with the
///    original selector. Unlike a proxy, `session.delegate` stays the app's own object.
/// 3. Callbacks from sessions that are not marked (foreground sessions sharing the delegate class)
///    are ignored: `CWURLProtocol` already captures those.
enum CWBackgroundSessionHook {

    nonisolated(unsafe) private static let sessionKey = CWRuntime.makeKey()
    private static let hookedClasses = CWLocked<Set<ObjectIdentifier>>([])

    private static let installation: Void = {
        let selector = NSSelectorFromString("sessionWithConfiguration:delegate:delegateQueue:")
        guard let meta = object_getClass(URLSession.self) else { return }
        typealias Factory = @convention(c) (AnyObject, Selector, URLSessionConfiguration, AnyObject?, OperationQueue?) -> URLSession
        CWRuntime.hook(meta, selector) { original in
            guard let original else { return { () -> Void in } as @convention(block) () -> Void }
            let factory = unsafeBitCast(original, to: Factory.self)
            let block: @convention(block) (AnyObject, URLSessionConfiguration, AnyObject?, OperationQueue?) -> URLSession = {
                type, configuration, delegate, queue in
                let session = factory(type, selector, configuration, delegate, queue)
                if configuration.identifier != nil {
                    observe(session, delegate: delegate)
                }
                return session
            }
            return block
        }
    }()

    /// Idempotent; does nothing to sessions until one is created with a background configuration.
    static func install() {
        _ = installation
    }

    /// Marks `session` as observed and hooks its delegate class. Internal so tests can observe a
    /// foreground session (background transfers cannot run inside a unit test).
    static func observe(_ session: URLSession, delegate: AnyObject?) {
        CWRuntime.associate(NSNumber(value: true), with: session, key: sessionKey)
        if let delegateClass = delegate.flatMap({ object_getClass($0) }) {
            hookDelegate(delegateClass)
        }
        if let sessionClass = object_getClass(session) {
            hookUploads(sessionClass)
        }
    }

    static func isObserved(_ session: URLSession) -> Bool {
        let marker: NSNumber? = CWRuntime.associated(session, key: sessionKey)
        return marker != nil
    }

    /// Records the class once; returns `false` when it was already hooked.
    private static func claim(_ type: AnyClass) -> Bool {
        hookedClasses.withLock { $0.insert(ObjectIdentifier(type)).inserted }
    }
}

// MARK: - Delegate hooks

private extension CWBackgroundSessionHook {

    static let taskDelegate = "NSURLSessionTaskDelegate"

    /// Metrics and completion are added when missing (no-op defaults in `URLSession`); download and
    /// data callbacks are hooked only when the app implements them, so `responds(to:)` stays the same.
    static func hookDelegate(_ type: AnyClass) {
        guard claim(type) else { return }
        hookMetrics(type)
        hookCompletion(type)
        hookDownload(type)
        hookData(type)
    }

    static func hookMetrics(_ type: AnyClass) {
        let selector = NSSelectorFromString("URLSession:task:didFinishCollectingMetrics:")
        typealias Original = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void
        CWRuntime.hook(type, selector, fallbackTypes: CWRuntime.types(of: selector, inProtocol: taskDelegate)) { original in
            let forward = original.map { unsafeBitCast($0, to: Original.self) }
            let block: @convention(block) (AnyObject, URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void = {
                delegate, session, task, metrics in
                if isObserved(session) {
                    CWBackgroundRecorder.didCollect(metrics, task: task)
                }
                forward?(delegate, selector, session, task, metrics)
            }
            return block
        }
    }

    static func hookCompletion(_ type: AnyClass) {
        let selector = NSSelectorFromString("URLSession:task:didCompleteWithError:")
        typealias Original = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, NSError?) -> Void
        CWRuntime.hook(type, selector, fallbackTypes: CWRuntime.types(of: selector, inProtocol: taskDelegate)) { original in
            let forward = original.map { unsafeBitCast($0, to: Original.self) }
            let block: @convention(block) (AnyObject, URLSession, URLSessionTask, NSError?) -> Void = {
                delegate, session, task, error in
                forward?(delegate, selector, session, task, error)
                if isObserved(session) {
                    CWBackgroundRecorder.didComplete(task, error: error)
                }
            }
            return block
        }
    }

    static func hookDownload(_ type: AnyClass) {
        let selector = NSSelectorFromString("URLSession:downloadTask:didFinishDownloadingToURL:")
        typealias Original = @convention(c) (AnyObject, Selector, URLSession, URLSessionDownloadTask, NSURL) -> Void
        CWRuntime.hook(type, selector) { original in
            let forward = original.map { unsafeBitCast($0, to: Original.self) }
            let block: @convention(block) (AnyObject, URLSession, URLSessionDownloadTask, NSURL) -> Void = {
                delegate, session, task, location in
                if isObserved(session) {
                    CWBackgroundRecorder.didFinishDownloading(task, to: location as URL)
                }
                forward?(delegate, selector, session, task, location)
            }
            return block
        }
    }

    static func hookData(_ type: AnyClass) {
        let selector = NSSelectorFromString("URLSession:dataTask:didReceiveData:")
        typealias Original = @convention(c) (AnyObject, Selector, URLSession, URLSessionDataTask, NSData) -> Void
        CWRuntime.hook(type, selector) { original in
            let forward = original.map { unsafeBitCast($0, to: Original.self) }
            let block: @convention(block) (AnyObject, URLSession, URLSessionDataTask, NSData) -> Void = {
                delegate, session, task, data in
                if isObserved(session) {
                    CWBackgroundRecorder.didReceive(data as Data, task: task)
                }
                forward?(delegate, selector, session, task, data)
            }
            return block
        }
    }
}

// MARK: - Upload files

private extension CWBackgroundSessionHook {

    /// Background uploads must come from a file; remember which one so its prefix can be shown.
    static func hookUploads(_ type: AnyClass) {
        guard claim(type) else { return }
        let selector = NSSelectorFromString("uploadTaskWithRequest:fromFile:")
        typealias Original = @convention(c) (AnyObject, Selector, NSURLRequest, NSURL) -> URLSessionUploadTask
        CWRuntime.hook(type, selector) { original in
            guard let original else { return { () -> Void in } as @convention(block) () -> Void }
            let create = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (URLSession, NSURLRequest, NSURL) -> URLSessionUploadTask = {
                session, request, file in
                let task = create(session, selector, request, file)
                if isObserved(session) {
                    CWBackgroundRecorder.didCreateUpload(task, fromFile: file as URL)
                }
                return task
            }
            return block
        }
    }
}
#endif
