//
//  CWHeadersTests.swift
//  CatWalk
//

import Testing
@testable import CatWalk

@Suite("CWHeaders")
struct CWHeadersTests {

    @Test("looks up values case-insensitively")
    func caseInsensitiveLookup() {
        let headers = CWHeaders(["Content-Type": "application/json"])

        #expect(headers["content-type"] == "application/json")
        #expect(headers["CONTENT-TYPE"] == "application/json")
        #expect(headers["Accept"] == nil)
    }

    @Test("sorts entries by name ignoring case")
    func sortedEntries() {
        let headers = CWHeaders(["b-header": "2", "A-Header": "1", "c": "3"])

        #expect(headers.entries.map(\.name) == ["A-Header", "b-header", "c"])
    }

    @Test("redacts only listed names and returns a new value")
    func redaction() {
        let original = CWHeaders(["Authorization": "Bearer secret", "Accept": "*/*"])

        let redacted = original.redacting(["authorization"])

        #expect(redacted["Authorization"] == CWRedaction.placeholder)
        #expect(redacted["Accept"] == "*/*")
        #expect(original["Authorization"] == "Bearer secret")
    }

    @Test("empty headers")
    func empty() {
        let headers = CWHeaders([:])

        #expect(headers.isEmpty)
        #expect(headers.entries.isEmpty)
    }
}
