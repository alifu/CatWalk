#if CATWALK_ENABLED
//
//  CWWebViewInstrumentation.swift
//  CatWalk
//

#if canImport(WebKit)
import Foundation
import ObjectiveC
import WebKit

/// Adds `CWWebViewScript` to web-view configurations, and optionally to every new `WKWebView`.
@MainActor
enum CWWebViewInstrumentation {

    private static let handler = CWWebViewMessageHandler()
    nonisolated(unsafe) private static let controllerKey = CWRuntime.makeKey()

    /// Adds the script and message handler once per user content controller (shared by copies of
    /// the configuration). Call before creating the web view: WebKit copies the configuration.
    static func instrument(_ configuration: WKWebViewConfiguration, limit: Int) {
        let controller = configuration.userContentController
        let marker: NSNumber? = CWRuntime.associated(controller, key: controllerKey)
        guard marker == nil else { return }
        CWRuntime.associate(NSNumber(value: true), with: controller, key: controllerKey)

        let script = WKUserScript(
            source: CWWebViewScript.source(limit: limit),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        )
        controller.addUserScript(script)
        controller.add(handler, contentWorld: .page, name: CWWebViewScript.messageHandlerName)
    }

    static func isInstrumented(_ configuration: WKWebViewConfiguration) -> Bool {
        let marker: NSNumber? = CWRuntime.associated(configuration.userContentController, key: controllerKey)
        return marker != nil
    }
}

// MARK: - Every new web view

extension CWWebViewInstrumentation {

    nonisolated private static let initialization: Void = {
        let selector = NSSelectorFromString("initWithFrame:configuration:")
        // Init methods consume `self` and return +1. Raw pointers keep ARC out of the hook, so ownership
        // passes from the caller to WebKit's original init and back untouched.
        typealias Original = @convention(c) (UnsafeRawPointer, Selector, CGRect, UnsafeRawPointer) -> UnsafeRawPointer?
        CWRuntime.hook(WKWebView.self, selector) { original in
            guard let original else { return { () -> Void in } as @convention(block) () -> Void }
            let initialize = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (UnsafeRawPointer, CGRect, UnsafeRawPointer) -> UnsafeRawPointer? = {
                webView, frame, configuration in
                let options = Unmanaged<WKWebViewConfiguration>.fromOpaque(configuration).takeUnretainedValue()
                MainActor.assumeIsolated { willCreateWebView(options) }
                let created = initialize(webView, selector, frame, configuration)
                if let created {
                    let createdWebView = Unmanaged<WKWebView>.fromOpaque(created).takeUnretainedValue()
                    MainActor.assumeIsolated { didCreateWebView(createdWebView) }
                }
                return created
            }
            return block
        }
    }()

    /// Hooks `-[WKWebView initWithFrame:configuration:]` once; the options are read on each init
    /// (always on the main thread, as WebKit requires).
    nonisolated static func installInitializationHook() {
        _ = initialization
    }

    private static func willCreateWebView(_ configuration: WKWebViewConfiguration) {
        let engine = CWCaptureEngine.shared
        let options = engine.recorder.configuration
        guard engine.isRunning, options.instrumentWebViews else { return }
        instrument(configuration, limit: options.maxBodyBytes)
    }

    private static func didCreateWebView(_ webView: WKWebView) {
        let engine = CWCaptureEngine.shared
        guard engine.isRunning, engine.recorder.configuration.makeWebViewsInspectable else { return }
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
    }
}

/// Receives `CWWebViewScript` messages. Held by WebKit for the controller's lifetime; holds nothing.
@MainActor
final class CWWebViewMessageHandler: NSObject, WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let engine = CWCaptureEngine.shared
        guard let event = CWWebViewEvent(message.body, limit: engine.recorder.configuration.maxBodyBytes) else { return }
        CWWebViewRecorder.record(event, engine: engine)
    }
}
#endif
#endif
