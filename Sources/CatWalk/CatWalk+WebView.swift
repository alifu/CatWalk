//
//  CatWalk+WebView.swift
//  CatWalk
//

#if canImport(WebKit)
import WebKit

extension CatWalk {

    /// Reports the `fetch` and `XMLHttpRequest` calls of pages in web views created with
    /// `configuration`. Call before creating the web view; calling again is harmless.
    ///
    /// Or set `CWConfiguration.instrumentWebViews` to do this for every new `WKWebView`.
    /// Images, styles, scripts and page loads are not reported: use Safari Web Inspector
    /// (`CWConfiguration.makeWebViewsInspectable`) for those.
    @MainActor
    public static func instrument(_ configuration: WKWebViewConfiguration) {
        #if CATWALK_ENABLED && !CATWALK_EXCLUDE_WEBVIEW
        CWWebViewInstrumentation.instrument(
            configuration,
            limit: CWCaptureEngine.shared.recorder.configuration.maxBodyBytes
        )
        #endif
    }
}
#endif
