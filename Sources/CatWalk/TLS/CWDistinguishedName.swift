#if CATWALK_ENABLED
//
//  CWDistinguishedName.swift
//  CatWalk
//

import Foundation

/// Renders an X.501 `Name` as `C=ID, O=Org, CN=host`, in certificate order (like `openssl x509 -subject`).
enum CWDistinguishedName {

    /// O(1) lookup of the common attribute short names; others print as dotted OIDs.
    private static let shortNames: [String: String] = [
        "2.5.4.3": "CN",
        "2.5.4.5": "serialNumber",
        "2.5.4.6": "C",
        "2.5.4.7": "L",
        "2.5.4.8": "ST",
        "2.5.4.9": "street",
        "2.5.4.10": "O",
        "2.5.4.11": "OU",
        "1.2.840.113549.1.9.1": "emailAddress",
        "0.9.2342.19200300.100.1.25": "DC",
    ]

    static func string(from name: CWDERElement) throws(CWDERError) -> String {
        var parts: [String] = []
        var sets = name.children()
        while !sets.isAtEnd {
            var attributes = try sets.next(expecting: CWDERElement.set).children()
            while !attributes.isAtEnd {
                var pair = try attributes.next(expecting: CWDERElement.sequence).children()
                let oid = try objectIdentifier(pair.next(expecting: CWDERElement.objectIdentifier).content)
                let value = try text(pair.next())
                parts.append("\(shortNames[oid] ?? oid)=\(value)")
            }
        }
        return parts.joined(separator: ", ")
    }

    static func objectIdentifier(_ bytes: ArraySlice<UInt8>) throws(CWDERError) -> String {
        guard let first = bytes.first else { throw .invalidValue }

        var components = first < 80 ? [Int(first / 40), Int(first % 40)] : [2, Int(first) - 80]
        var value = 0
        for byte in bytes.dropFirst() {
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 {
                components.append(value)
                value = 0
            }
        }
        return components.map(String.init).joined(separator: ".")
    }

    private static func text(_ element: CWDERElement) throws(CWDERError) -> String {
        let decoded: String?
        switch element.tag {
        case CWDERElement.bmpString:
            decoded = String(data: Data(element.content), encoding: .utf16BigEndian)
        case CWDERElement.teletexString:
            decoded = String(data: Data(element.content), encoding: .isoLatin1)
        default:
            decoded = String(bytes: element.content, encoding: .utf8)
        }
        guard let decoded else { throw .invalidValue }
        return decoded
    }
}
#endif
