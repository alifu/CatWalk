//
//  CWDERReader.swift
//  CatWalk
//

import Foundation

enum CWDERError: Error, Sendable, Equatable {
    case truncated
    case unsupportedLength
    case unexpectedTag(expected: UInt8, found: UInt8)
    case invalidValue
}

/// One DER tag-length-value element.
struct CWDERElement: Sendable {

    static let integer: UInt8 = 0x02
    static let objectIdentifier: UInt8 = 0x06
    static let utf8String: UInt8 = 0x0C
    static let printableString: UInt8 = 0x13
    static let teletexString: UInt8 = 0x14
    static let ia5String: UInt8 = 0x16
    static let utcTime: UInt8 = 0x17
    static let generalizedTime: UInt8 = 0x18
    static let bmpString: UInt8 = 0x1E
    static let sequence: UInt8 = 0x30
    static let set: UInt8 = 0x31
    /// `[0] EXPLICIT`, used for the X.509 version field.
    static let contextSpecific0: UInt8 = 0xA0

    let tag: UInt8
    /// Value bytes only.
    let content: ArraySlice<UInt8>
    /// Whole element, header included (what an SPKI pin hashes).
    let encoded: ArraySlice<UInt8>

    func children() -> CWDERReader {
        CWDERReader(content)
    }

    func expecting(_ tag: UInt8) throws(CWDERError) -> CWDERElement {
        guard self.tag == tag else { throw .unexpectedTag(expected: tag, found: self.tag) }
        return self
    }
}

/// Minimal DER reader: definite lengths up to 4 bytes, low tag numbers only —
/// everything an X.509 certificate needs. O(1) per element; slices share the input buffer.
struct CWDERReader: Sendable {

    private static let maxLengthBytes = 4

    private let bytes: ArraySlice<UInt8>
    private var position: Int

    init(_ bytes: ArraySlice<UInt8>) {
        self.bytes = bytes
        self.position = bytes.startIndex
    }

    init(_ data: Data) {
        self.init(ArraySlice(data))
    }

    var isAtEnd: Bool {
        position >= bytes.endIndex
    }

    mutating func next() throws(CWDERError) -> CWDERElement {
        let start = position
        let tag = try readByte()
        guard tag & 0x1F != 0x1F else { throw .unsupportedLength }

        let length = try readLength()
        guard length <= bytes.endIndex - position else { throw .truncated }

        let content = bytes[position..<(position + length)]
        position += length
        return CWDERElement(tag: tag, content: content, encoded: bytes[start..<position])
    }

    mutating func next(expecting tag: UInt8) throws(CWDERError) -> CWDERElement {
        try next().expecting(tag)
    }

    private mutating func readByte() throws(CWDERError) -> UInt8 {
        guard position < bytes.endIndex else { throw .truncated }
        defer { position += 1 }
        return bytes[position]
    }

    private mutating func readLength() throws(CWDERError) -> Int {
        let first = try readByte()
        guard first & 0x80 != 0 else { return Int(first) }

        let count = Int(first & 0x7F)
        guard (1...Self.maxLengthBytes).contains(count) else { throw .unsupportedLength }

        var length = 0
        for _ in 0..<count {
            length = (length << 8) | Int(try readByte())
        }
        return length
    }
}
