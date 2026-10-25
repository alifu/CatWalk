#if CATWALK_ENABLED
//
//  CWCertificate.swift
//  CatWalk
//

import CryptoKit
import Foundation
import os
import Security

/// One certificate of a server's chain, leaf first.
public struct CWCertificate: Sendable, Equatable, Identifiable {

    public struct PublicKey: Sendable, Equatable {
        /// `RSA`, `EC` or the raw `kSecAttrKeyType` value.
        public let type: String
        public let sizeInBits: Int
    }

    public var id: String { sha256Fingerprint }

    public let derData: Data

    /// `SecCertificateCopySubjectSummary`, usually the common name.
    public let summary: String?

    public let subject: String?
    public let issuer: String?
    public let serialNumber: String?
    public let notBefore: Date?
    public let notAfter: Date?

    /// SHA-256 of the whole certificate, `AB:CD:…`.
    public let sha256Fingerprint: String

    /// Base64 SHA-256 of `SubjectPublicKeyInfo`: the value public-key pinning compares.
    public let publicKeySHA256: String?

    public let publicKey: PublicKey?

    private static let logger = Logger(subsystem: "com.catwalk", category: "tls")

    init(_ certificate: SecCertificate) {
        let der = SecCertificateCopyData(certificate) as Data
        let fields: CWX509Fields?
        do {
            fields = try CWX509Parser.parse(der)
        } catch {
            Self.logger.error("Could not parse certificate: \(String(describing: error), privacy: .public)")
            fields = nil
        }

        derData = der
        summary = SecCertificateCopySubjectSummary(certificate) as String?
        subject = fields?.subject
        issuer = fields?.issuer
        serialNumber = fields?.serialNumber
        notBefore = fields?.notBefore
        notAfter = fields?.notAfter
        sha256Fingerprint = CWHex.colonSeparated(SHA256.hash(data: der))
        publicKeySHA256 = fields.map { Data(SHA256.hash(data: $0.subjectPublicKeyInfo)).base64EncodedString() }
        publicKey = Self.publicKey(of: certificate)
    }

    /// Leaf-first chain of a server trust. O(chain length × certificate size).
    static func chain(of trust: SecTrust) -> [CWCertificate] {
        let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
        return certificates.map(CWCertificate.init)
    }

    private static func publicKey(of certificate: SecCertificate) -> PublicKey? {
        guard
            let key = SecCertificateCopyKey(certificate),
            let attributes = SecKeyCopyAttributes(key) as? [CFString: Any],
            let type = attributes[kSecAttrKeyType] as? String,
            let size = attributes[kSecAttrKeySizeInBits] as? Int
        else {
            return nil
        }
        return PublicKey(type: keyTypeNames[type] ?? type, sizeInBits: size)
    }

    private static let keyTypeNames: [String: String] = [
        kSecAttrKeyTypeRSA as String: "RSA",
        kSecAttrKeyTypeECSECPrimeRandom as String: "EC",
    ]
}
#endif
