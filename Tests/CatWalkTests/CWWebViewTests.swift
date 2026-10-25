#if CATWALK_ENABLED
//
//  CWWebViewTests.swift
//  CatWalk
//
//  Real WKWebViews loading pages from `TestSchemeHandler`, so no network is needed.
//

import Foundation
import Testing
import WebKit
@testable import CatWalk

extension SharedEngine {

    @Suite("Web views", .serialized)
    @MainActor
    final class CWWebViewTests {

        let engine = CWCaptureEngine.shared

        init() {
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: []))
        }

        deinit {
            CWCaptureEngine.shared.stop()
        }

        private func rows(host: String) -> [CWTransaction] {
            engine.store.snapshot().filter { $0.request.url.host == host }
        }

        /// Waits (spinning the main run loop for WebKit) until `count` finished rows exist for `host`.
        private func finishedRows(host: String, count: Int) async -> [CWTransaction] {
            for _ in 0..<250 {
                let found = rows(host: host).filter { $0.state != .inFlight }
                if found.count >= count { return found }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            return rows(host: host)
        }

        private func load(_ configuration: WKWebViewConfiguration, host: String) -> WKWebView {
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: configuration)
            webView.load(URLRequest(url: URL(string: "\(TestSchemeHandler.scheme)://\(host)/index.html")!))
            return webView
        }

        private func configuration(_ handler: TestSchemeHandler) -> WKWebViewConfiguration {
            let configuration = WKWebViewConfiguration()
            configuration.setURLSchemeHandler(handler, forURLScheme: TestSchemeHandler.scheme)
            return configuration
        }

        @Test("fetch POST and XHR GET from an instrumented page are recorded with bodies")
        func fetchAndXHR() async throws {
            let handler = TestSchemeHandler()
            let configuration = configuration(handler)
            CatWalk.instrument(configuration)
            let webView = load(configuration, host: "page.test")
            defer { _ = webView }

            let rows = await finishedRows(host: "page.test", count: 2)
            let post = try #require(rows.first { $0.request.method == "POST" })
            let get = try #require(rows.first { $0.request.method == "GET" })

            #expect(post.source == .webView)
            #expect(post.state == .completed)
            #expect(post.request.url.path == "/api/echo")
            #expect(post.request.body?.data == Data(#"{"name":"cat"}"#.utf8))
            #expect(post.request.headers["Authorization"] == CWRedaction.placeholder)
            #expect(post.response?.statusCode == 201)
            #expect(post.response?.body?.data == Data(#"{"echo":{"name":"cat"}}"#.utf8))
            #expect(post.response?.headers["X-Reply"] == "yes")
            #expect(get.request.url.path == "/api/items")
            #expect(get.request.headers["X-Client"] == "xhr")
            #expect(get.response?.statusCode == 200)
            #expect(get.response?.body?.data == Data(#"{"items":[1,2]}"#.utf8))
            #expect(!post.isMockable)
        }

        @Test("instrumenting twice adds the script once")
        func idempotent() {
            let configuration = WKWebViewConfiguration()

            CatWalk.instrument(configuration)
            CatWalk.instrument(configuration)

            let scripts = configuration.userContentController.userScripts
            #expect(scripts.filter { $0.source.contains(CWWebViewScript.installedMarker) }.count == 1)
        }

        @Test("instrumentWebViews instruments new web views; makeWebViewsInspectable sets isInspectable")
        func automatic() throws {
            engine.start(configuration: CWConfiguration(
                interceptCustomSessions: false, triggers: [], instrumentWebViews: true, makeWebViewsInspectable: true
            ))
            let instrumented = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

            engine.start(configuration: CWConfiguration(
                interceptCustomSessions: false, triggers: [], instrumentWebViews: false, makeWebViewsInspectable: false
            ))
            let plain = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

            #expect(CWWebViewInstrumentation.isInstrumented(instrumented.configuration))
            #expect(!CWWebViewInstrumentation.isInstrumented(plain.configuration))
            if #available(iOS 16.4, *) {
                #expect(instrumented.isInspectable)
                #expect(!plain.isInspectable)
            }
        }

        @Test("the init hook keeps ownership balanced: hooked web views are released, not leaked")
        func releasesWebViews() async {
            engine.start(configuration: CWConfiguration(
                interceptCustomSessions: false, triggers: [], instrumentWebViews: true, makeWebViewsInspectable: true
            ))
            weak var released: WKWebView?
            autoreleasepool {
                let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
                let subclassed = CustomWebView(frame: .zero)
                released = webView
                #expect(CWWebViewInstrumentation.isInstrumented(subclassed.configuration))
            }
            for _ in 0..<50 where released != nil {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            #expect(released == nil)
        }

        @Test("web views made after the hook still work: page loads and its requests finish")
        func pageStillWorks() async throws {
            engine.start(configuration: CWConfiguration(
                interceptCustomSessions: false, triggers: [], instrumentWebViews: true
            ))
            let handler = TestSchemeHandler()
            let webView = load(configuration(handler), host: "auto.test")
            defer { _ = webView }

            let rows = await finishedRows(host: "auto.test", count: 2)
            #expect(rows.count == 2)
            #expect(handler.servedPaths.contains("/index.html"))
        }

        @Test("a failed fetch is recorded as failed; nothing is recorded while stopped")
        func failureAndStopped() async throws {
            let ok: [String: Any] = ["cw": 1, "id": "t-1", "phase": "start", "method": "GET", "url": "https://fail.test/x"]
            let error: [String: Any] = ["cw": 1, "id": "t-1", "phase": "error", "message": "Load failed"]
            CWWebViewRecorder.record(try #require(CWWebViewEvent(ok, limit: 100)))
            CWWebViewRecorder.record(try #require(CWWebViewEvent(error, limit: 100)))

            let failed = try #require(rows(host: "fail.test").first)
            #expect(failed.state == .failed)
            #expect(failed.error?.message == "Load failed")
            #expect(failed.error?.domain == CWWebViewRecorder.errorDomain)

            let stopped = CWCaptureEngine()
            let quiet: [String: Any] = ["cw": 1, "id": "t-2", "phase": "start", "method": "GET", "url": "https://quiet.test/x"]
            CWWebViewRecorder.record(try #require(CWWebViewEvent(quiet, limit: 100)), engine: stopped)
            #expect(stopped.store.count == 0)
        }
    }
}

/// A subclass initialised through `init(frame:)`, which reaches the hooked designated init via `super`.
final class CustomWebView: WKWebView {}

/// Serves a page that makes one `fetch` POST and one XHR GET, plus the two API answers.
final class TestSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "catwalk-test"

    private(set) var servedPaths: [String] = []

    private static let page = #"""
    <!doctype html><html><body><script>
    fetch('/api/echo', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer secret' },
                         body: JSON.stringify({ name: 'cat' }) });
    var xhr = new XMLHttpRequest();
    xhr.open('GET', '/api/items');
    xhr.setRequestHeader('X-Client', 'xhr');
    xhr.send();
    </script></body></html>
    """#

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        servedPaths.append(url.path)
        let (status, type, body, extra): (Int, String, Data, [String: String]) = switch url.path {
        case "/index.html": (200, "text/html", Data(Self.page.utf8), [:])
        case "/api/echo": (201, "application/json", Data(#"{"echo":"#.utf8) + (task.request.httpBody ?? Data()) + Data("}".utf8), ["X-Reply": "yes"])
        case "/api/items": (200, "application/json", Data(#"{"items":[1,2]}"#.utf8), [:])
        default: (404, "text/plain", Data("missing".utf8), [:])
        }
        let headers = ["Content-Type": type, "Content-Length": String(body.count)].merging(extra) { $1 }
        task.didReceive(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!)
        task.didReceive(body)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
#endif
