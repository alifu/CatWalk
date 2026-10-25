//
//  CWMockRule+Builder.swift
//  CatWalk
//

import Foundation

/// Rule under construction: pick a request with `CWMockRule.get(...)`, finish with `respond`/`fail`.
public struct CWMockRuleBuilder: Sendable {

    fileprivate let matcher: CWMockMatcher

    /// Only requests carrying these headers match.
    public func headers(_ headers: [String: String]) -> CWMockRuleBuilder {
        var updated = matcher
        updated.requiredHeaders = headers
        return CWMockRuleBuilder(matcher: updated)
    }

    public func respond(
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        delay: TimeInterval = 0
    ) -> CWMockRule {
        CWMockRule(matcher: matcher, response: CWMockResponse(status: status, headers: headers, body: body, delay: delay))
    }

    /// Answers with `object` serialized as JSON and `Content-Type: application/json`.
    public func respond(
        status: Int = 200,
        json object: Any,
        headers: [String: String] = [:],
        delay: TimeInterval = 0
    ) -> CWMockRule {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
        return respond(
            status: status,
            headers: headers.merging(["Content-Type": "application/json"]) { custom, _ in custom },
            body: body,
            delay: delay
        )
    }

    /// Fails the request with `error`, e.g. `.notConnectedToInternet`.
    public func fail(with error: URLError.Code, delay: TimeInterval = 0) -> CWMockRule {
        CWMockRule(matcher: matcher, response: CWMockResponse(delay: delay, error: error))
    }
}

extension CWMockRule {

    /// `CWMockRule.get("/products").respond(status: 200, json: ["items": []])`.
    /// A string containing `://` is matched as the full URL, anything else as a path.
    public static func get(_ url: String) -> CWMockRuleBuilder { request("GET", url) }

    public static func post(_ url: String) -> CWMockRuleBuilder { request("POST", url) }

    public static func put(_ url: String) -> CWMockRuleBuilder { request("PUT", url) }

    public static func patch(_ url: String) -> CWMockRuleBuilder { request("PATCH", url) }

    public static func delete(_ url: String) -> CWMockRuleBuilder { request("DELETE", url) }

    /// Any method, any URL form (`.exact`, `.prefix`, `.regex`, …).
    public static func matching(_ url: CWURLMatch, method: String? = nil) -> CWMockRuleBuilder {
        CWMockRuleBuilder(matcher: CWMockMatcher(method: method, url: url))
    }

    private static func request(_ method: String, _ url: String) -> CWMockRuleBuilder {
        matching(url.contains("://") ? .exact(url) : .path(url), method: method)
    }
}
