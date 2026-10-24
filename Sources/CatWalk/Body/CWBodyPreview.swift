//
//  CWBodyPreview.swift
//  CatWalk
//

import Foundation

/// How a captured body is shown, chosen from its content type and bytes.
enum CWBodyPreview: Equatable {
    case empty
    /// Bytes were dropped after a memory warning; only the size is known.
    case purged(totalBytes: Int)
    case json(CWJSONNode, pretty: String)
    case text(String)
    case image(Data)
    case binary(hexDump: String)

    static let hexDumpLimit = 512

    static func make(for body: CWBody?, mimeType: String?) -> CWBodyPreview {
        guard let body, body.totalBytes > 0 else { return .empty }
        guard !body.data.isEmpty else { return .purged(totalBytes: body.totalBytes) }

        let mime = mimeType?.lowercased() ?? ""
        if mime.hasPrefix("image/") {
            return .image(body.data)
        }
        if let json = jsonPreview(body.data, mime: mime) {
            return json
        }
        if let text = String(data: body.data, encoding: .utf8) {
            return .text(text)
        }
        return .binary(hexDump: hexDump(body.data))
    }

    private static func jsonPreview(_ data: Data, mime: String) -> CWBodyPreview? {
        guard mime.contains("json") || looksLikeJSON(data), let node = CWJSONNode(data: data) else { return nil }

        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
        let pretty = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: options) }
            .flatMap { String(data: $0, encoding: .utf8) }
        return .json(node, pretty: pretty ?? String(decoding: data, as: UTF8.self))
    }

    private static func looksLikeJSON(_ data: Data) -> Bool {
        guard let first = data.first(where: { $0 != 0x20 && $0 != 0x0A && $0 != 0x0D && $0 != 0x09 }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    private static func hexDump(_ data: Data) -> String {
        data.prefix(hexDumpLimit)
            .enumerated()
            .map { String(format: "%02x", $0.element) + ($0.offset % 16 == 15 ? "\n" : " ") }
            .joined()
    }
}
