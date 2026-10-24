//
//  CWBodyPreviewTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWBodyPreview and CWJSONNode")
struct CWBodyPreviewTests {

    private func body(_ text: String) -> CWBody { CWBody(capturing: Data(text.utf8), limit: 1 << 20) }

    @Test("JSON is detected by content type or by shape and pretty-printed with sorted keys")
    func json() throws {
        let byType = CWBodyPreview.make(for: body(#"{"b":1,"a":[true,null]}"#), mimeType: "application/json")
        let byShape = CWBodyPreview.make(for: body("  [1]"), mimeType: "text/plain")

        guard case let .json(node, pretty) = byType else { Issue.record("expected json, got \(byType)"); return }
        #expect(node == .object([
            .init(key: "a", node: .array([.bool(true), .null])),
            .init(key: "b", node: .number("1")),
        ]))
        #expect(pretty.contains("\"a\" : [") && pretty.range(of: "\"a\"")!.lowerBound < pretty.range(of: "\"b\"")!.lowerBound)
        guard case .json = byShape else { Issue.record("expected json, got \(byShape)"); return }
    }

    @Test("a truncated JSON body falls back to text")
    func truncatedJSON() {
        let truncated = CWBody(data: Data(#"{"a":"#.utf8), totalBytes: 100)

        #expect(CWBodyPreview.make(for: truncated, mimeType: "application/json") == .text(#"{"a":"#))
    }

    @Test("empty, purged, image and binary bodies")
    func otherKinds() {
        let png = CWBody(data: Data([1, 2, 3]), totalBytes: 3)
        let binary = CWBody(data: Data([0xFF, 0x00, 0x10]), totalBytes: 3)

        #expect(CWBodyPreview.make(for: nil, mimeType: nil) == .empty)
        #expect(CWBodyPreview.make(for: CWBody(data: Data(), totalBytes: 9), mimeType: nil) == .purged(totalBytes: 9))
        #expect(CWBodyPreview.make(for: png, mimeType: "image/png") == .image(Data([1, 2, 3])))
        #expect(CWBodyPreview.make(for: binary, mimeType: "application/octet-stream") == .binary(hexDump: "ff 00 10 "))
    }

    @Test("scalars and containers summarise themselves")
    func summaries() throws {
        let node = try #require(CWJSONNode(data: Data(#"{"s":"x","n":1.5,"o":{},"l":[1,2]}"#.utf8)))

        guard case let .object(members) = node else { Issue.record("expected object"); return }
        #expect(members.map(\.node.summary) == ["[2]", "1.5", "{0}", "\"x\""])
        #expect(node.childCount == 4)
        #expect(CWJSONNode.null.childCount == nil)
    }
}
