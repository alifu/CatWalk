//
//  CWX509Parser.swift
//  CatWalk
//

import Foundation

/// Fields read from a certificate's DER without OpenSSL.
struct CWX509Fields: Sendable, Equatable {
    let serialNumber: String
    let issuer: String
    let subject: String
    let notBefore: Date
    let notAfter: Date
    /// DER of `SubjectPublicKeyInfo`, header included.
    let subjectPublicKeyInfo: Data
}

/// Reads the `TBSCertificate` header fields (RFC 5280 §4.1). O(size of the certificate).
enum CWX509Parser {

    static func parse(_ der: Data) throws(CWDERError) -> CWX509Fields {
        var outer = CWDERReader(der)
        let certificate = try outer.next(expecting: CWDERElement.sequence)
        var certificateFields = certificate.children()
        let tbs = try certificateFields.next(expecting: CWDERElement.sequence)

        var fields = tbs.children()
        var serial = try fields.next()
        if serial.tag == CWDERElement.contextSpecific0 {
            serial = try fields.next()
        }
        _ = try serial.expecting(CWDERElement.integer)
        _ = try fields.next(expecting: CWDERElement.sequence) // signature algorithm
        let issuer = try fields.next(expecting: CWDERElement.sequence)
        var validity = try fields.next(expecting: CWDERElement.sequence).children()
        let notBefore = try CWDERTime.date(from: validity.next())
        let notAfter = try CWDERTime.date(from: validity.next())
        let subject = try fields.next(expecting: CWDERElement.sequence)
        let spki = try fields.next(expecting: CWDERElement.sequence)

        return CWX509Fields(
            serialNumber: hexSerial(serial.content),
            issuer: try CWDistinguishedName.string(from: issuer),
            subject: try CWDistinguishedName.string(from: subject),
            notBefore: notBefore,
            notAfter: notAfter,
            subjectPublicKeyInfo: Data(spki.encoded)
        )
    }

    /// Colon-separated upper-case hex, without the sign-padding zero byte.
    private static func hexSerial(_ bytes: ArraySlice<UInt8>) -> String {
        let trimmed = bytes.count > 1 && bytes.first == 0 ? bytes.dropFirst() : bytes
        return CWHex.colonSeparated(trimmed)
    }
}

enum CWHex {
    static func colonSeparated<Bytes: Sequence<UInt8>>(_ bytes: Bytes) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
