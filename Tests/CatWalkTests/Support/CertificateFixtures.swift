//
//  CertificateFixtures.swift
//  CatWalk
//
//  Self-signed test certificates generated with OpenSSL 3.6.3; expected values come from
//  `openssl x509 -noout -subject -serial -dates -fingerprint -sha256` and the SPKI SHA-256.
//

import Foundation
import Security

enum CertificateFixtures {

    /// RSA 2048, C=ID, O=CatWalk Test, OU=QA, CN=rsa.catwalk.test, serial 01:02:03:04:05,
    /// validity 2026-10-24 16:58:58Z – 2036-10-21 16:58:58Z (both UTCTime).
    static let rsaBase64 = "MIIDajCCAlKgAwIBAgIFAQIDBAUwDQYJKoZIhvcNAQELBQAwTDELMAkGA1UEBhMCSUQxFTATBgNVBAoMDENhdFdhbGsgVGVzdDELMAkGA1UECwwCUUExGTAXBgNVBAMMEHJzYS5jYXR3YWxrLnRlc3QwHhcNMjYxMDI0MTY1ODU4WhcNMzYxMDIxMTY1ODU4WjBMMQswCQYDVQQGEwJJRDEVMBMGA1UECgwMQ2F0V2FsayBUZXN0MQswCQYDVQQLDAJRQTEZMBcGA1UEAwwQcnNhLmNhdHdhbGsudGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAI9NNZOVgOvpA0U6HK3ldMrvRgg/9S7HknycM4f9zdX55eyyUjZn7Jq8g8OuJb55actDCGrtfNv4Nn/Zm/OR9FbdhlScuDDXs7TS95QgfZ8Wbvnk7kSExJzZKBqjcCSQ1RXCygBCa/KxwaxDPMOQg65mw/rn1ieXBAzSfhSHmG2Wb6JYgQqE/PnQrInqnBSVAhzQz3fHRuqcpeEfsVo1Bcvwhvqdes1fzRpU3LhXCjZcXgeqOil1o3Ug8ALmiHLx9tIKQ8030oUYV3iuzLmowyn03CTF38W8CexGgT3lfyzQ1aLpMPPf8FEdfljcXjncrsInQGULtQ6WJYrmGLC6v/sCAwEAAaNTMFEwHQYDVR0OBBYEFPFhzJa70zbIvi2oE3WLYS+6CJqCMB8GA1UdIwQYMBaAFPFhzJa70zbIvi2oE3WLYS+6CJqCMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAEY1H8gbUmt10mN+lWv7fsKnkTvju4UbYXcxWZNeV3nu1uqHRhXk5yRACcDH6zPm9ywCl3AvRFf1t+HGZ0CWM39NzgvHjyabKRTkI2QfaxHhK/tXJ+/TK/HeWvqqO2QaTmE4O3oIgEJULjxfnimdmERUoUg/gsahuBBdw3S/c8AEGgL0ivMFESycxpH4I1jP+xouRkRUBoDtDclth5ZSZYJU/Z+km8PzFayLFYMBAQPb4aE3ACCSdf1ozsJJv5rsxrzPtFklq9h3klHjCr0K9sqb7ivqht7bpLNnd5/ZWGPFGgYZIc2g1PC4qHMpsNFkTW68VcRC06FI/l6aFcNE6Tw="

    /// EC P-256, CN=ec.catwalk.test, O=CatWalk Test, serial 2A,
    /// validity 2026-10-24 16:58:58Z (UTCTime) – 2052-10-27 16:58:58Z (GeneralizedTime).
    static let ecBase64 = "MIIBpTCCAUygAwIBAgIBKjAKBggqhkjOPQQDAjAxMRgwFgYDVQQDDA9lYy5jYXR3YWxrLnRlc3QxFTATBgNVBAoMDENhdFdhbGsgVGVzdDAgFw0yNjEwMjQxNjU4NThaGA8yMDUyMTAyNzE2NTg1OFowMTEYMBYGA1UEAwwPZWMuY2F0d2Fsay50ZXN0MRUwEwYDVQQKDAxDYXRXYWxrIFRlc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATAVHN99RjgUUyywZVf2EhgfZmmHpSxZzHiiF04IOTM786ylWOmIeOx2EgbarlLUAiX1a4jAJvwyzZNL/jadb59o1MwUTAdBgNVHQ4EFgQUq0vlVocWa80Po3bLl0fvrt3lDrEwHwYDVR0jBBgwFoAUq0vlVocWa80Po3bLl0fvrt3lDrEwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNHADBEAiBqd3TTQnrjS2XXUBq3qWfHEzEociB/VcTd4llbVrltkgIgL14U0WJ3FAxNDxMLRj5tCx88Poft8xeNpSdqqEd8UYU="

    static var rsaDER: Data { Data(base64Encoded: rsaBase64)! }
    static var ecDER: Data { Data(base64Encoded: ecBase64)! }

    static var rsaCertificate: SecCertificate { SecCertificateCreateWithData(nil, rsaDER as CFData)! }
    static var ecCertificate: SecCertificate { SecCertificateCreateWithData(nil, ecDER as CFData)! }

    static func trust(_ certificates: [SecCertificate]) -> SecTrust {
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificates as CFArray, SecPolicyCreateSSL(true, nil), &trust)
        return trust!
    }
}
