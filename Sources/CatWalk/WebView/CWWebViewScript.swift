#if CATWALK_ENABLED
//
//  CWWebViewScript.swift
//  CatWalk
//

import Foundation

/// JavaScript injected at document start (all frames, page world) that reports `fetch` and
/// `XMLHttpRequest` calls to the `catwalk` message handler.
///
/// It only observes: arguments, return values and promises reach the page unchanged, and every
/// step is wrapped in `try`. Response bodies are read from a `clone()` and only for textual
/// content types; other bodies are reported by size. Strings are capped at `limit` characters.
enum CWWebViewScript {

    static let messageHandlerName = "catwalk"

    /// Marker the page sees as `window.__catwalkInstalled`; also stops a second injection.
    static let installedMarker = "__catwalkInstalled"

    static func source(limit: Int) -> String {
        template
            .replacingOccurrences(of: "__CW_LIMIT__", with: String(max(0, limit)))
            .replacingOccurrences(of: "__CW_HANDLER__", with: messageHandlerName)
            .replacingOccurrences(of: "__CW_MARKER__", with: installedMarker)
    }

    private static let template = #"""
    (function () {
      'use strict';
      var handler;
      try {
        handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.__CW_HANDLER__;
        if (!handler || window.__CW_MARKER__) { return; }
        Object.defineProperty(window, '__CW_MARKER__', { value: true });
      } catch (e) { return; }

      var LIMIT = __CW_LIMIT__;
      var prefix = Math.random().toString(36).slice(2);
      var sequence = 0;
      var textType = /json|text|xml|javascript|x-www-form-urlencoded|graphql/i;

      function post(message) {
        try { message.cw = 1; message.time = Date.now(); handler.postMessage(message); } catch (e) {}
      }
      function nextID() { sequence += 1; return prefix + '-' + sequence; }
      function absolute(url) {
        try { return new URL(String(url), document.baseURI).href; } catch (e) { return String(url); }
      }
      function byteLength(text) {
        try { return new TextEncoder().encode(text).length; } catch (e) { return text.length; }
      }
      function textBody(text) {
        text = String(text);
        return { text: text.length > LIMIT ? text.slice(0, LIMIT) : text, size: byteLength(text) };
      }
      function sizeOnly(size) { return { text: null, size: Number(size) || 0 }; }
      function requestBody(body) {
        if (body === undefined || body === null) { return sizeOnly(0); }
        if (typeof body === 'string') { return textBody(body); }
        if (typeof URLSearchParams !== 'undefined' && body instanceof URLSearchParams) { return textBody(body.toString()); }
        if (typeof Blob !== 'undefined' && body instanceof Blob) { return sizeOnly(body.size); }
        if (body.byteLength !== undefined) { return sizeOnly(body.byteLength); }
        return sizeOnly(0);
      }
      function headerObject(headers) {
        var result = {};
        try {
          if (!headers) { return result; }
          if (Array.isArray(headers)) {
            headers.forEach(function (pair) { result[String(pair[0])] = String(pair[1]); });
          } else if (typeof headers.forEach === 'function') {
            headers.forEach(function (value, name) { result[name] = String(value); });
          } else {
            Object.keys(headers).forEach(function (name) { result[name] = String(headers[name]); });
          }
        } catch (e) {}
        return result;
      }
      function rawHeaderObject(raw) {
        var result = {};
        String(raw || '').trim().split(/[\r\n]+/).forEach(function (line) {
          var index = line.indexOf(':');
          if (index > 0) { result[line.slice(0, index).trim()] = line.slice(index + 1).trim(); }
        });
        return result;
      }
      function start(id, api, method, url, headers, body) {
        post({ id: id, phase: 'start', api: api, method: String(method || 'GET').toUpperCase(),
               url: absolute(url), headers: headers, body: body.text, bodySize: body.size });
      }
      function finish(id, status, headers, body) {
        post({ id: id, phase: 'end', status: status, headers: headers, body: body.text, bodySize: body.size });
      }
      function fail(id, message) { post({ id: id, phase: 'error', message: String(message || 'Network error') }); }

      var originalFetch = window.fetch;
      if (typeof originalFetch === 'function') {
        window.fetch = function (input, init) {
          var result = originalFetch.apply(this, arguments);
          try {
            var request = (typeof Request !== 'undefined' && input instanceof Request) ? input : null;
            var id = nextID();
            start(id, 'fetch', (init && init.method) || (request && request.method), request ? request.url : input,
                  headerObject((init && init.headers) || (request && request.headers)), requestBody(init && init.body));
            result.then(function (response) {
              try {
                if (response.type === 'opaque') { fail(id, 'Opaque (no-cors) response: status and body are hidden from the page'); return; }
                var headers = headerObject(response.headers);
                var length = response.headers.get('content-length');
                if (!textType.test(response.headers.get('content-type') || '')) {
                  finish(id, response.status, headers, sizeOnly(length)); return;
                }
                response.clone().text().then(
                  function (text) { finish(id, response.status, headers, textBody(text)); },
                  function () { finish(id, response.status, headers, sizeOnly(length)); });
              } catch (e) {}
            }, function (error) { fail(id, error && error.message); });
          } catch (e) {}
          return result;
        };
      }

      var XHR = window.XMLHttpRequest;
      if (XHR && XHR.prototype) {
        var pending = new WeakMap();
        var open = XHR.prototype.open;
        var setRequestHeader = XHR.prototype.setRequestHeader;
        var send = XHR.prototype.send;
        XHR.prototype.open = function (method, url) {
          try { pending.set(this, { method: method, url: url, headers: {} }); } catch (e) {}
          return open.apply(this, arguments);
        };
        XHR.prototype.setRequestHeader = function (name, value) {
          try { var info = pending.get(this); if (info) { info.headers[String(name)] = String(value); } } catch (e) {}
          return setRequestHeader.apply(this, arguments);
        };
        XHR.prototype.send = function (body) {
          try {
            var info = pending.get(this);
            if (info) {
              var xhr = this;
              var id = nextID();
              start(id, 'xhr', info.method, info.url, info.headers, requestBody(body));
              xhr.addEventListener('loadend', function () {
                try {
                  if (xhr.status === 0) { fail(id, 'Request failed, was aborted or timed out'); return; }
                  var type = xhr.responseType;
                  var payload = (type === '' || type === 'text') ? textBody(xhr.responseText)
                    : type === 'json' ? textBody(JSON.stringify(xhr.response))
                    : sizeOnly(xhr.response && (xhr.response.byteLength || xhr.response.size));
                  finish(id, xhr.status, rawHeaderObject(xhr.getAllResponseHeaders()), payload);
                } catch (e) {}
              });
            }
          } catch (e) {}
          return send.apply(this, arguments);
        };
      }
    })();
    """#
}
#endif
