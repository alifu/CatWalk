//
//  CWMockDraftTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWMockDraft")
struct CWMockDraftTests {

    @Test("pre-fills from a response, dropping transfer headers")
    func prefill() throws {
        let transaction = TransactionFixtures.make(
            "GET", "https://api.test/items", status: 503, responseBody: Data(#"{"e":1}"#.utf8)
        )

        let draft = CWMockDraft(from: transaction)

        #expect(draft.method == "GET")
        #expect(draft.pattern == "https://api.test/items")
        #expect(draft.status == "503")
        #expect(draft.headersText == "Content-Type: application/json")
        #expect(draft.body == #"{"e":1}"#)
    }

    @Test("builds a rule and round-trips through an existing rule")
    func roundTrip() throws {
        var draft = CWMockDraft()
        draft.method = "post"
        draft.kind = .prefix
        draft.pattern = " https://api.test/v1 "
        draft.status = "201"
        draft.headersText = "X-A: b: c\n\n Y : z "
        draft.body = "ok"
        draft.delay = 1.5

        let rule = try draft.rule(isEnabled: false)

        #expect(rule.matcher == CWMockMatcher(method: "POST", url: .prefix("https://api.test/v1")))
        #expect(rule.response == CWMockResponse(status: 201, headers: ["X-A": "b: c", "Y": "z"], body: Data("ok".utf8), delay: 1.5))
        #expect(!rule.isEnabled)
        #expect(CWMockDraft(from: rule).id == rule.id)
        #expect(try CWMockDraft(from: rule).rule().matcher == rule.matcher)
    }

    @Test("rejects an empty pattern, a bad status and a malformed header")
    func validation() {
        var draft = CWMockDraft()
        #expect(throws: CWMockDraft.ValidationError.emptyPattern) { try draft.rule() }

        draft.pattern = "/p"
        draft.status = "99"
        #expect(throws: CWMockDraft.ValidationError.invalidStatus) { try draft.rule() }

        draft.status = "200"
        draft.headersText = "no colon here"
        #expect(throws: CWMockDraft.ValidationError.invalidHeader("no colon here")) { try draft.rule() }
    }
}
