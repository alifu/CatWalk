#if CATWALK_ENABLED
//
//  CWWebViewEvent.swift
//  CatWalk
//

import Foundation

/// A validated message from `CWWebViewScript`.
///
/// Any page script can post to the handler, so every field is checked and capped here:
/// malformed messages are dropped, never trusted.
enum CWWebViewEvent: Equatable {

    struct Start: Equatable {
        let id: String
        let method: String
        let url: URL
        let headers: [String: String]
        let body: CWBody?
        let date: Date
    }

    struct End: Equatable {
        let id: String
        let status: Int
        let headers: [String: String]
        let body: CWBody?
        let date: Date
    }

    case start(Start)
    case end(End)
    case failure(id: String, message: String, date: Date)

    static let maxIDLength = 64
    static let maxMethodLength = 16
    static let maxHeaderCount = 100
    static let maxHeaderNameLength = 256
    static let maxHeaderValueLength = 8 * 1024
    static let maxMessageLength = 500

    /// - Parameter limit: bytes kept per body (`CWConfiguration.maxBodyBytes`).
    init?(_ message: Any, limit: Int) {
        guard
            let fields = message as? [String: Any],
            (fields["cw"] as? Int) == 1,
            let id = fields["id"] as? String,
            (1...Self.maxIDLength).contains(id.count)
        else {
            return nil
        }
        let date = Self.date(fields["time"])

        switch fields["phase"] as? String {
        case "start":
            guard
                let method = Self.method(fields["method"]),
                let url = (fields["url"] as? String).flatMap(URL.init(string:)),
                url.scheme != nil
            else {
                return nil
            }
            self = .start(Start(
                id: id, method: method, url: url,
                headers: Self.headers(fields["headers"]),
                body: Self.body(fields["body"], size: fields["bodySize"], limit: limit),
                date: date
            ))
        case "end":
            guard let status = fields["status"] as? Int, (100...599).contains(status) else { return nil }
            self = .end(End(
                id: id, status: status,
                headers: Self.headers(fields["headers"]),
                body: Self.body(fields["body"], size: fields["bodySize"], limit: limit),
                date: date
            ))
        case "error":
            let message = (fields["message"] as? String).map { String($0.prefix(Self.maxMessageLength)) } ?? "Network error"
            self = .failure(id: id, message: message, date: date)
        default:
            return nil
        }
    }

    var id: String {
        switch self {
        case let .start(start): start.id
        case let .end(end): end.id
        case let .failure(id, _, _): id
        }
    }
}

private extension CWWebViewEvent {

    /// Letters only (`GET`, `POST`, custom verbs), as HTTP tokens allow.
    static func method(_ value: Any?) -> String? {
        guard let method = (value as? String)?.uppercased(),
              (1...maxMethodLength).contains(method.count),
              method.allSatisfy({ $0.isASCII && $0.isLetter })
        else {
            return nil
        }
        return method
    }

    static func headers(_ value: Any?) -> [String: String] {
        guard let fields = value as? [String: Any] else { return [:] }
        let valid = fields.lazy
            .compactMap { name, value -> (String, String)? in
                guard let value = value as? String,
                      (1...maxHeaderNameLength).contains(name.count),
                      value.count <= maxHeaderValueLength
                else {
                    return nil
                }
                return (name, value)
            }
            .prefix(maxHeaderCount)
        return Dictionary(Array(valid), uniquingKeysWith: { _, last in last })
    }

    /// Text bodies are capped in bytes; size-only bodies (binary, blobs) are `nil`.
    static func body(_ text: Any?, size: Any?, limit: Int) -> CWBody? {
        guard let text = text as? String else { return nil }
        let data = Data(text.utf8)
        let reported = max(0, (size as? Int) ?? 0)
        return CWBody(data: Data(data.prefix(max(0, limit))), totalBytes: max(reported, data.count))
    }

    /// JavaScript milliseconds since 1970; the receive time when missing or implausible.
    static func date(_ value: Any?) -> Date {
        guard let milliseconds = value as? Double, milliseconds.isFinite, milliseconds > 0 else { return Date() }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}
#endif
