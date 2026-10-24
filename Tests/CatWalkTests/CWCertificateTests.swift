//
//  CWCertificateTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWCertificate")
struct CWCertificateTests {

    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        ))
    }

    @Test("parses an RSA certificate with UTCTime validity")
    func rsa() {
        let certificate = CWCertificate(CertificateFixtures.rsaCertificate)

        #expect(certificate.summary == "rsa.catwalk.test")
        #expect(certificate.subject == "C=ID, O=CatWalk Test, OU=QA, CN=rsa.catwalk.test")
        #expect(certificate.issuer == certificate.subject)
        #expect(certificate.serialNumber == "01:02:03:04:05")
        #expect(certificate.notBefore == utc(2026, 10, 24, 16, 58, 58))
        #expect(certificate.notAfter == utc(2036, 10, 21, 16, 58, 58))
        #expect(certificate.sha256Fingerprint
            == "A0:02:A0:E9:A5:3E:1F:67:2D:05:78:5C:3A:F0:FE:49:53:2E:E2:52:3C:8A:16:58:72:1E:9E:27:FC:57:E0:47")
        #expect(certificate.publicKeySHA256 == "ZTUFJH2qApGQmrUx1gVkh6uSrSPHfMHg0avLJy0zhI8=")
        #expect(certificate.publicKey == CWCertificate.PublicKey(type: "RSA", sizeInBits: 2048))
        #expect(certificate.derData == CertificateFixtures.rsaDER)
    }

    @Test("parses an EC certificate with GeneralizedTime validity")
    func ec() {
        let certificate = CWCertificate(CertificateFixtures.ecCertificate)

        #expect(certificate.subject == "CN=ec.catwalk.test, O=CatWalk Test")
        #expect(certificate.serialNumber == "2A")
        #expect(certificate.notAfter == utc(2052, 10, 27, 16, 58, 58))
        #expect(certificate.publicKeySHA256 == "fJrIkmURbOa80K6JbHlYh2fT9mEx0Pma27jZvMFdIWQ=")
        #expect(certificate.publicKey == CWCertificate.PublicKey(type: "EC", sizeInBits: 256))
    }

    @Test("chain(of:) returns the trust's certificates leaf first")
    func chain() {
        let trust = CertificateFixtures.trust([CertificateFixtures.rsaCertificate, CertificateFixtures.ecCertificate])

        let chain = CWCertificate.chain(of: trust)

        #expect(chain.first?.summary == "rsa.catwalk.test")
        #expect(!chain.isEmpty)
    }

    @Test("truncated DER fails to parse instead of reading out of bounds")
    func truncated() {
        let der = CertificateFixtures.rsaDER.prefix(200)

        #expect(throws: CWDERError.truncated) {
            try CWX509Parser.parse(Data(der))
        }
    }
}

@Suite("CWDERReader")
struct CWDERReaderTests {

    @Test("reads short and long form lengths")
    func lengths() throws {
        let long = [UInt8](repeating: 7, count: 200)
        var reader = CWDERReader(Data([0x02, 0x01, 0x05, 0x04, 0x81, 0xC8] + long))

        let short = try reader.next(expecting: CWDERElement.integer)
        let octets = try reader.next()

        #expect(Array(short.content) == [5])
        #expect(octets.content.count == 200)
        #expect(octets.encoded.count == 203)
        #expect(reader.isAtEnd)
    }

    @Test("rejects malformed input", arguments: [
        ([0x02, 0x05, 0x01], CWDERError.truncated),
        ([0x02, 0x80], CWDERError.unsupportedLength),
        ([0x02, 0x85, 0, 0, 0, 0, 1], CWDERError.unsupportedLength),
        ([0x1F, 0x01, 0x00], CWDERError.unsupportedLength),
        ([0x02], CWDERError.truncated),
    ] as [([UInt8], CWDERError)])
    func malformed(bytes: [UInt8], error: CWDERError) {
        var reader = CWDERReader(Data(bytes))

        #expect(throws: error) {
            try reader.next()
        }
    }

    @Test("unexpected tags are reported")
    func unexpectedTag() {
        var reader = CWDERReader(Data([0x30, 0x00]))

        #expect(throws: CWDERError.unexpectedTag(expected: 0x02, found: 0x30)) {
            try reader.next(expecting: CWDERElement.integer)
        }
    }

    @Test("decodes object identifiers")
    func oid() throws {
        #expect(try CWDistinguishedName.objectIdentifier([0x55, 0x04, 0x03]) == "2.5.4.3")
        #expect(try CWDistinguishedName.objectIdentifier([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01])
            == "1.2.840.113549.1.9.1")
    }

    @Test("UTCTime years below 50 are 20xx, others 19xx")
    func utcPivot() throws {
        func year(_ text: String) throws -> Int {
            let element = CWDERElement(
                tag: CWDERElement.utcTime,
                content: ArraySlice(Array(text.utf8)),
                encoded: []
            )
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return calendar.component(.year, from: try CWDERTime.date(from: element))
        }

        #expect(try year("491231235959Z") == 2049)
        #expect(try year("500101000000Z") == 1950)
        #expect(throws: CWDERError.invalidValue) { try year("5001010000Z") }
        #expect(throws: CWDERError.invalidValue) { try year("501301000000Z") }
    }
}

@Suite("CWTLSNames")
struct CWTLSNamesTests {

    @Test("known and unknown codes")
    func names() {
        #expect(CWTLSNames.protocolName(0x0304) == "TLS 1.3")
        #expect(CWTLSNames.cipherSuiteName(0x1301) == "TLS_AES_128_GCM_SHA256")
        #expect(CWTLSNames.cipherSuiteName(0x00AB) == "0x00AB")
    }
}

@Suite("CWCertificateCache")
struct CWCertificateCacheTests {

    @Test("stores per host and port, bounded")
    func bounded() {
        let cache = CWCertificateCache(limit: 2)
        let chain = [CWCertificate(CertificateFixtures.rsaCertificate)]

        cache.store(chain, for: "a:443")
        cache.store(chain, for: "b:443")
        cache.store(chain, for: "c:443")
        cache.store([], for: "d:443")

        #expect(cache.chain(for: "c:443") == chain)
        #expect(cache.chain(for: "a:443") == nil)
        #expect(cache.chain(for: "d:443") == nil)
    }

    @Test("keys use the default port for the scheme")
    func keys() throws {
        #expect(CWCertificateCache.key(for: try #require(URL(string: "https://API.test/x"))) == "api.test:443")
        #expect(CWCertificateCache.key(for: try #require(URL(string: "https://a.test:8443"))) == "a.test:8443")
    }
}
