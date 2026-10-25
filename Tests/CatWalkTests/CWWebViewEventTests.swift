#if CATWALK_ENABLED
//
//  CWWebViewEventTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("Web view messages")
struct CWWebViewEventTests {

    private func start(_ overrides: [String: Any] = [:]) -> [String: Any] {
        let base: [String: Any] = [
            "cw": 1, "id": "abc-1", "phase": "start", "method": "post", "url": "https://web.test/api?q=1",
            "headers": ["Content-Type": "application/json"], "body": #"{"a":1}"#, "bodySize": 7, "time": 1_700_000_000_000.0,
        ]
        return base.merging(overrides) { _, new in new }
    }

    @Test("a start message becomes a validated request")
    func parsesStart() throws {
        guard case let .start(start)? = CWWebViewEvent(start(), limit: 1024) else {
            Issue.record("not parsed as start")
            return
        }
        #expect(start.method == "POST")
        #expect(start.url.absoluteString == "https://web.test/api?q=1")
        #expect(start.headers == ["Content-Type": "application/json"])
        #expect(start.body?.data == Data(#"{"a":1}"#.utf8))
        #expect(start.date == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("malformed or hostile messages are dropped", arguments: [
        ["cw": "2"],
        ["id": ""],
        ["id": String(repeating: "x", count: 65)],
        ["phase": "launch"],
        ["method": "GET /x"],
        ["url": "not a url"],
    ] as [[String: String]])
    func rejects(_ override: [String: String]) {
        #expect(CWWebViewEvent(start(override), limit: 1024) == nil)
        #expect(CWWebViewEvent("just a string", limit: 1024) == nil)
    }

    @Test("ends need a real HTTP status; failures keep a capped message")
    func endsAndFailures() {
        let end: [String: Any] = ["cw": 1, "id": "abc-1", "phase": "end", "status": 0]
        let failure: [String: Any] = ["cw": 1, "id": "abc-1", "phase": "error", "message": String(repeating: "m", count: 900)]

        #expect(CWWebViewEvent(end, limit: 1024) == nil)
        guard case let .failure(_, message, _)? = CWWebViewEvent(failure, limit: 1024) else {
            Issue.record("not parsed as failure")
            return
        }
        #expect(message.count == CWWebViewEvent.maxMessageLength)
    }

    @Test("bodies are capped in bytes and keep the reported size; headers are bounded")
    func caps() throws {
        let headers = Dictionary(uniqueKeysWithValues: (0..<150).map { ("X-\($0)", "v") })
        let event = CWWebViewEvent(start(["body": "ééééé", "bodySize": 4000, "headers": headers]), limit: 4)

        guard case let .start(start)? = event else {
            Issue.record("not parsed as start")
            return
        }
        #expect(start.body?.data.count == 4)
        #expect(start.body?.totalBytes == 4000)
        #expect(start.headers.count == CWWebViewEvent.maxHeaderCount)
    }

    @Test("pending ids are bounded; the oldest go first")
    func pendingBound() {
        var pending = CWPendingRequests(limit: 2)
        let ids = (0..<3).map { _ in UUID() }
        ids.enumerated().forEach { pending.insert($1, for: "k\($0)") }

        #expect(pending.count == 2)
        #expect(pending.remove("k0") == nil)
        #expect(pending.remove("k2") == ids[2])
    }
}
#endif
