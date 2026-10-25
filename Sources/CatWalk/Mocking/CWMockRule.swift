//
//  CWMockRule.swift
//  CatWalk
//

import Foundation

/// How a rule matches the request URL.
public enum CWURLMatch: Sendable, Equatable {
    /// The full absolute URL, e.g. `https://api.example.com/products?page=1`.
    case exact(String)
    /// Only the URL path, on any host (query ignored), e.g. `/products`.
    case path(String)
    /// The absolute URL starts with this text.
    case prefix(String)
    /// The absolute URL contains this text.
    case contains(String)
    /// An `NSRegularExpression` pattern searched in the absolute URL.
    case regex(String)
}

/// Which requests a rule applies to. All set conditions must hold.
public struct CWMockMatcher: Sendable, Equatable {

    /// `nil` matches any method; compared case-insensitively.
    public var method: String?

    public var url: CWURLMatch

    /// Header values the request must carry (names and values compared case-insensitively).
    public var requiredHeaders: [String: String]

    public init(method: String? = nil, url: CWURLMatch, requiredHeaders: [String: String] = [:]) {
        self.method = method
        self.url = url
        self.requiredHeaders = requiredHeaders
    }
}

/// The canned answer for a matched request. The network is never contacted.
public struct CWMockResponse: Sendable, Equatable {

    public var status: Int

    public var headers: [String: String]

    public var body: Data

    /// Seconds to wait before answering.
    public var delay: TimeInterval

    /// When set, the request fails with this error instead of answering.
    public var error: URLError.Code?

    public init(
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        delay: TimeInterval = 0,
        error: URLError.Code? = nil
    ) {
        self.status = status
        self.headers = headers
        self.body = body
        self.delay = max(0, delay)
        self.error = error
    }
}

/// A request matcher plus the response to give. Immutable: changes return a copy with the same `id`.
public struct CWMockRule: Sendable, Identifiable, Equatable {

    public let id: UUID

    public let isEnabled: Bool

    public let matcher: CWMockMatcher

    public let response: CWMockResponse

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        matcher: CWMockMatcher,
        response: CWMockResponse
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.matcher = matcher
        self.response = response
    }

    public func enabled(_ isEnabled: Bool) -> CWMockRule {
        CWMockRule(id: id, isEnabled: isEnabled, matcher: matcher, response: response)
    }
}
