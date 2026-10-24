//
//  CWMockStoreTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWMockStore")
struct CWMockStoreTests {

    private func request(_ url: String, method: String = "GET", headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private func rule(_ url: CWURLMatch, method: String? = nil, status: Int = 200, headers: [String: String] = [:]) -> CWMockRule {
        CWMockRule(
            matcher: CWMockMatcher(method: method, url: url, requiredHeaders: headers),
            response: CWMockResponse(status: status)
        )
    }

    @Test("exact beats a regex added earlier")
    func exactBeatsRegex() throws {
        let store = CWMockStore()
        let regex = rule(.regex(#"/products"#), status: 201)
        let exact = rule(.exact("https://a.test/products"), status: 202)
        try store.add(regex)
        try store.add(exact)

        #expect(store.match(request("https://a.test/products"))?.id == exact.id)
        #expect(store.match(request("https://b.test/products"))?.id == regex.id)
    }

    @Test("each URL form matches as documented", arguments: [
        (CWURLMatch.exact("https://a.test/p?x=1"), "https://a.test/p?x=1", true),
        (.exact("https://a.test/p"), "https://a.test/p?x=1", false),
        (.path("/p"), "https://other.test/p?x=1", true),
        (.path("/p"), "https://a.test/p/1", false),
        (.prefix("https://a.test/api"), "https://a.test/api/v1", true),
        (.prefix("https://a.test/api"), "https://b.test/api", false),
        (.contains("v1"), "https://a.test/api/v1/x", true),
        (.regex(#"/users/\d+$"#), "https://a.test/users/42", true),
        (.regex(#"/users/\d+$"#), "https://a.test/users/me", false),
    ])
    func urlForms(match: CWURLMatch, url: String, expected: Bool) throws {
        let store = CWMockStore()
        try store.add(rule(match))

        #expect((store.match(request(url)) != nil) == expected)
    }

    @Test("method and required headers must match; method ignores case")
    func methodAndHeaders() throws {
        let store = CWMockStore()
        try store.add(rule(.path("/p"), method: "post", headers: ["X-Env": "Staging"]))

        #expect(store.match(request("https://a.test/p", method: "POST", headers: ["x-env": "staging"])) != nil)
        #expect(store.match(request("https://a.test/p", method: "GET", headers: ["X-Env": "staging"])) == nil)
        #expect(store.match(request("https://a.test/p", method: "POST")) == nil)
    }

    @Test("disabled rules are skipped and re-enabling restores them")
    func disabledRule() throws {
        let store = CWMockStore()
        let mock = rule(.path("/p"))
        try store.add(mock)
        store.setEnabled(false, for: mock.id)

        #expect(store.match(request("https://a.test/p")) == nil)

        store.setEnabled(true, for: mock.id)
        #expect(store.match(request("https://a.test/p"))?.id == mock.id)
    }

    @Test("counts hits; removing a rule clears its index and count")
    func hitsAndRemoval() throws {
        let store = CWMockStore()
        let mock = rule(.exact("https://a.test/p"))
        try store.add(mock)
        _ = store.match(request("https://a.test/p"))
        _ = store.match(request("https://a.test/p"))
        _ = store.match(request("https://a.test/other"))

        #expect(store.hitCount(for: mock.id) == 2)

        store.remove(id: mock.id)

        #expect(store.match(request("https://a.test/p")) == nil)
        #expect(store.hitCount(for: mock.id) == 0)
        #expect(store.rules.isEmpty)
    }

    @Test("re-adding an id replaces the rule in place and reindexes it")
    func replacingRule() throws {
        let store = CWMockStore()
        let first = rule(.exact("https://a.test/old"))
        let other = rule(.path("/other"))
        try store.add(first)
        try store.add(other)
        let replacement = CWMockRule(
            id: first.id,
            matcher: CWMockMatcher(url: .exact("https://a.test/new")),
            response: CWMockResponse(status: 204)
        )
        try store.add(replacement)

        #expect(store.rules.map(\.id) == [first.id, other.id])
        #expect(store.match(request("https://a.test/old")) == nil)
        #expect(store.match(request("https://a.test/new"))?.response.status == 204)
    }

    @Test("an invalid regex is rejected and nothing is stored")
    func invalidRegex() {
        let store = CWMockStore()

        #expect(throws: CWConfigurationError.invalidMockPattern("(")) {
            try store.add(rule(.regex("(")))
        }
        #expect(store.rules.isEmpty)
    }

    @Test("builder maps path vs full URL and JSON bodies")
    func builder() throws {
        let path = CWMockRule.get("/products").respond(status: 200, json: ["b": 1, "a": 2])
        let full = CWMockRule.post("https://a.test/x").fail(with: .timedOut)

        #expect(path.matcher.url == .path("/products"))
        #expect(path.matcher.method == "GET")
        #expect(path.response.headers["Content-Type"] == "application/json")
        #expect(String(data: path.response.body, encoding: .utf8) == #"{"a":2,"b":1}"#)
        #expect(full.matcher.url == .exact("https://a.test/x"))
        #expect(full.response.error == .timedOut)
    }
}
