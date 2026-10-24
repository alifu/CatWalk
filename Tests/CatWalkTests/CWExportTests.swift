#if CATWALK_ENABLED
//
//  CWExportTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("Exporters and replay")
struct CWExportTests {

    @Test("cURL: method, quoted URL, headers and body; GET has no -X")
    func curl() {
        let post = TransactionFixtures.make(
            "POST", "https://api.test/o?x=1", requestBody: Data("it's".utf8), headers: ["X-A": "b"]
        )
        let get = TransactionFixtures.make("GET", "https://api.test/o")

        let command = CWCurlExporter.command(for: post)

        #expect(command.contains("-X POST"))
        #expect(command.contains("'https://api.test/o?x=1'"))
        #expect(command.contains("-H 'X-A: b'"))
        #expect(command.contains("--data-raw 'it'\\''s'"))
        #expect(!CWCurlExporter.command(for: get).contains("-X"))
    }

    @Test("cURL notes a binary body instead of inventing text")
    func curlBinary() {
        let transaction = TransactionFixtures.make("PUT", requestBody: Data([0xFF, 0xFE, 0x00]))

        #expect(CWCurlExporter.command(for: transaction).contains("binary body of 3 bytes omitted"))
    }

    @Test("HAR is valid 1.2 JSON with request, response and content")
    func har() throws {
        let transaction = TransactionFixtures.make(
            "GET", "https://api.test/items?page=2", responseBody: Data(#"{"a":1}"#.utf8)
        )

        let data = try CWHARExporter.data(for: [transaction])

        let log = try #require((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["log"] as? [String: Any])
        let entry = try #require((log["entries"] as? [[String: Any]])?.first)
        let request = try #require(entry["request"] as? [String: Any])
        let response = try #require(entry["response"] as? [String: Any])
        let content = try #require(response["content"] as? [String: Any])
        #expect(log["version"] as? String == "1.2")
        #expect(request["method"] as? String == "GET")
        #expect((request["queryString"] as? [[String: String]])?.first == ["name": "page", "value": "2"])
        #expect(response["status"] as? Int == 200)
        #expect(content["text"] as? String == #"{"a":1}"#)
    }

    @Test("HAR encodes a binary response as base64")
    func harBinary() throws {
        let bytes = Data([0xFF, 0xFE])
        let data = try CWHARExporter.data(for: [TransactionFixtures.make(responseBody: bytes)])

        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(bytes.base64EncodedString()))
        #expect(text.contains("\"encoding\" : \"base64\""))
    }

    @Test("replay drops redacted headers and truncated bodies")
    func replay() throws {
        let headers = CWHeaders(["Authorization": CWRedaction.placeholder, "X-Keep": "1"])
        let full = CWHTTPRequest(
            method: "POST", url: URL(string: "https://a.test")!, headers: headers,
            body: CWBody(data: Data("hi".utf8), totalBytes: 2)
        )
        let truncated = CWHTTPRequest(
            method: "POST", url: URL(string: "https://a.test")!, headers: headers,
            body: CWBody(data: Data("h".utf8), totalBytes: 2)
        )

        #expect(full.replayRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(full.replayRequest.value(forHTTPHeaderField: "X-Keep") == "1")
        #expect(full.replayRequest.httpBody == Data("hi".utf8))
        #expect(truncated.replayRequest.httpBody == nil)
    }
}
#endif
