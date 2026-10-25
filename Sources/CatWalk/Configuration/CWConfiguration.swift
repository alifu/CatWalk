//
//  CWConfiguration.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

/// Capture options passed to `CatWalk.start(configuration:)`.
public struct CWConfiguration: Sendable {

    public static let defaultMaxBodyBytes = 1024 * 1024

    public static let defaultMaxTransactions = 500

    public static let defaultMaxTotalBodyBytes = 50 * 1024 * 1024

    public static let defaultMaxFramesPerConnection = 1000

    /// `true` in Debug builds, `false` in Release builds that keep CatWalk (`CatWalkAlwaysOn`).
    public static let defaultMakeWebViewsInspectable: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()

    public static let defaultRedactedHeaders: Set<String> = ["Authorization", "Proxy-Authorization"]

    /// Bytes kept per request/response body; the full body is still delivered to the app.
    public var maxBodyBytes: Int

    /// Header names (case-insensitive) whose values are replaced by `CWRedaction.placeholder`.
    /// Include `Cookie` / `Set-Cookie` to also hide cookie values. Pass `[]` to see everything.
    public var redactedHeaders: Set<String>

    /// Inject capture into every `URLSessionConfiguration.default` / `.ephemeral`
    /// (custom sessions, Alamofire). Sessions created before `start` are not affected.
    public var interceptCustomSessions: Bool

    /// Transactions kept in memory; the oldest are evicted first.
    public var maxTransactions: Int

    /// Upper bound for all captured bodies together; the oldest transactions are evicted first.
    public var maxTotalBodyBytes: Int

    /// Hosts that are never captured: `api.example.com`, or `*.example.com` for the domain and
    /// all its subdomains. Invalid entries are skipped and logged.
    public var ignoredHosts: [String]

    /// What opens the inspector. Default: shake. Use `[]` to open it only from your own code.
    public var triggers: CWTrigger

    /// Record `URLSessionWebSocketTask` handshakes and messages (read-only; never changes what is sent).
    public var captureWebSockets: Bool

    /// Messages kept per WebSocket connection; the oldest are dropped first.
    public var maxFramesPerConnection: Int

    /// Inject a script into every new `WKWebView` that reports page `fetch` / `XMLHttpRequest` calls.
    /// Off by default; `CatWalk.instrument(_:)` does the same for one configuration.
    public var instrumentWebViews: Bool

    /// Set `isInspectable` on every new `WKWebView` (iOS 16.4+), so Safari Web Inspector shows all
    /// of its traffic, including images, styles and page loads that the script can't see.
    public var makeWebViewsInspectable: Bool

    /// `false` turns CatWalk off without removing it: `start` does nothing. Feed it from a remote flag.
    public var isEnabled: Bool

    public init(
        maxBodyBytes: Int = CWConfiguration.defaultMaxBodyBytes,
        redactedHeaders: Set<String> = CWConfiguration.defaultRedactedHeaders,
        interceptCustomSessions: Bool = true,
        maxTransactions: Int = CWConfiguration.defaultMaxTransactions,
        maxTotalBodyBytes: Int = CWConfiguration.defaultMaxTotalBodyBytes,
        ignoredHosts: [String] = [],
        triggers: CWTrigger = [.shake],
        captureWebSockets: Bool = true,
        maxFramesPerConnection: Int = CWConfiguration.defaultMaxFramesPerConnection,
        instrumentWebViews: Bool = false,
        makeWebViewsInspectable: Bool = CWConfiguration.defaultMakeWebViewsInspectable,
        isEnabled: Bool = true
    ) {
        self.maxBodyBytes = max(0, maxBodyBytes)
        self.maxTransactions = max(1, maxTransactions)
        self.maxTotalBodyBytes = max(0, maxTotalBodyBytes)
        self.ignoredHosts = ignoredHosts
        self.triggers = triggers
        self.captureWebSockets = captureWebSockets
        self.maxFramesPerConnection = max(1, maxFramesPerConnection)
        self.instrumentWebViews = instrumentWebViews
        self.makeWebViewsInspectable = makeWebViewsInspectable
        self.isEnabled = isEnabled
        self.redactedHeaders = redactedHeaders
        self.interceptCustomSessions = interceptCustomSessions
    }

    public static let `default` = CWConfiguration()
}
