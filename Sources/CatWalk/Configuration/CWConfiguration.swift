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

    public static let defaultRedactedHeaders: Set<String> = ["Authorization", "Proxy-Authorization"]

    /// Bytes kept per request/response body; the full body is still delivered to the app.
    public var maxBodyBytes: Int

    /// Header names (case-insensitive) whose values are replaced by `CWRedaction.placeholder`.
    /// Include `Cookie` / `Set-Cookie` to also hide cookie values. Pass `[]` to see everything.
    public var redactedHeaders: Set<String>

    /// Inject capture into every `URLSessionConfiguration.default` / `.ephemeral`
    /// (custom sessions, Alamofire). Sessions created before `start` are not affected.
    public var interceptCustomSessions: Bool

    public init(
        maxBodyBytes: Int = CWConfiguration.defaultMaxBodyBytes,
        redactedHeaders: Set<String> = CWConfiguration.defaultRedactedHeaders,
        interceptCustomSessions: Bool = true
    ) {
        self.maxBodyBytes = max(0, maxBodyBytes)
        self.redactedHeaders = redactedHeaders
        self.interceptCustomSessions = interceptCustomSessions
    }

    public static let `default` = CWConfiguration()
}
