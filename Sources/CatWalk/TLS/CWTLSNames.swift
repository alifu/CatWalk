//
//  CWTLSNames.swift
//  CatWalk
//

/// Display names for IANA TLS protocol and cipher-suite codes. O(1) lookups.
enum CWTLSNames {

    static func protocolName(_ code: UInt16) -> String {
        protocols[code] ?? hex(code)
    }

    static func cipherSuiteName(_ code: UInt16) -> String {
        cipherSuites[code] ?? hex(code)
    }

    private static func hex(_ code: UInt16) -> String {
        "0x" + String(code, radix: 16, uppercase: true).leftPadded(to: 4)
    }

    private static let protocols: [UInt16: String] = [
        0x0300: "SSL 3.0",
        0x0301: "TLS 1.0",
        0x0302: "TLS 1.1",
        0x0303: "TLS 1.2",
        0x0304: "TLS 1.3",
        0xFEFF: "DTLS 1.0",
        0xFEFD: "DTLS 1.2",
    ]

    private static let cipherSuites: [UInt16: String] = [
        0x1301: "TLS_AES_128_GCM_SHA256",
        0x1302: "TLS_AES_256_GCM_SHA384",
        0x1303: "TLS_CHACHA20_POLY1305_SHA256",
        0xC02B: "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        0xC02C: "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        0xC02F: "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        0xC030: "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
        0xCCA8: "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
        0xCCA9: "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
        0xC009: "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA",
        0xC00A: "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",
        0xC013: "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA",
        0xC014: "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
        0xC023: "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
        0xC024: "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384",
        0xC027: "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
        0xC028: "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384",
        0x009C: "TLS_RSA_WITH_AES_128_GCM_SHA256",
        0x009D: "TLS_RSA_WITH_AES_256_GCM_SHA384",
        0x002F: "TLS_RSA_WITH_AES_128_CBC_SHA",
        0x0035: "TLS_RSA_WITH_AES_256_CBC_SHA",
        0x003C: "TLS_RSA_WITH_AES_128_CBC_SHA256",
        0x003D: "TLS_RSA_WITH_AES_256_CBC_SHA256",
        0x000A: "TLS_RSA_WITH_3DES_EDE_CBC_SHA",
    ]
}

private extension String {
    func leftPadded(to length: Int) -> String {
        String(repeating: "0", count: max(0, length - count)) + self
    }
}
