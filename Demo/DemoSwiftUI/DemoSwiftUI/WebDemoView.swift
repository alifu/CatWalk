//
//  WebDemoView.swift
//  DemoSwiftUI
//

import CatWalk
import SwiftUI
import WebKit

/// A page whose `fetch` and `XMLHttpRequest` calls CatWalk reports ("WEB" rows).
/// `CatWalk.instrument(_:)` must run before the web view is created.
struct WebDemoView: UIViewRepresentable {

    private static let page = """
    <!doctype html>
    <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
    <body style="font: -apple-system-body; padding: 16px">
    <h3>Web view demo</h3>
    <p id="product">Loading with fetch…</p>
    <p id="cart">Posting with XMLHttpRequest…</p>
    <script>
    fetch('https://dummyjson.com/products/1')
      .then(function (response) { return response.json(); })
      .then(function (product) { document.getElementById('product').textContent = 'fetch: ' + product.title; });
    var xhr = new XMLHttpRequest();
    xhr.open('POST', 'https://dummyjson.com/carts/add');
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.onload = function () { document.getElementById('cart').textContent = 'XHR: ' + xhr.status; };
    xhr.send(JSON.stringify({ userId: 1, products: [{ id: 1, quantity: 2 }] }));
    </script>
    </body></html>
    """

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        CatWalk.instrument(configuration)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadHTMLString(Self.page, baseURL: URL(string: "https://dummyjson.com/"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
