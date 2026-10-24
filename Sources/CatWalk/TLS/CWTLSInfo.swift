//
//  CWTLSInfo.swift
//  CatWalk
//

import Foundation

/// How the app's session answered the server-trust challenge.
public enum CWTrustDecision: Sendable, Equatable {
    /// System trust evaluation (no custom delegate, or the delegate deferred to it).
    case defaultHandling
    /// The delegate accepted the server with its own credential (e.g. after pinning checks).
    case usedCredential
    /// The delegate rejected the server (e.g. a pinning failure).
    case cancelled
    case rejectedProtectionSpace
}

/// Connection and certificate details of an HTTPS exchange.
public struct CWTLSInfo: Sendable, Equatable {

    /// IANA code, e.g. `0x0304`; see `protocolName`.
    public let protocolVersion: UInt16?

    /// IANA code, e.g. `0x1301`; see `cipherSuiteName`.
    public let cipherSuite: UInt16?

    public let isProxyConnection: Bool

    /// A reused connection has no handshake, so its chain comes from an earlier one.
    public let isReusedConnection: Bool

    public let remoteAddress: String?

    public let remotePort: Int?

    /// Leaf first.
    public let certificates: [CWCertificate]

    /// `true` when no handshake happened on this load and `certificates` were seen
    /// earlier for the same host and port.
    public let isChainFromEarlierConnection: Bool

    /// `nil` when no server-trust challenge happened on this load.
    public let trustDecision: CWTrustDecision?

    public var protocolName: String? {
        protocolVersion.map(CWTLSNames.protocolName)
    }

    public var cipherSuiteName: String? {
        cipherSuite.map(CWTLSNames.cipherSuiteName)
    }

    init(
        connection: CWConnectionMetrics?,
        certificates: [CWCertificate],
        isChainFromEarlierConnection: Bool,
        trustDecision: CWTrustDecision?
    ) {
        protocolVersion = connection?.tlsProtocolVersion
        cipherSuite = connection?.tlsCipherSuite
        isProxyConnection = connection?.isProxyConnection ?? false
        isReusedConnection = connection?.isReusedConnection ?? false
        remoteAddress = connection?.remoteAddress
        remotePort = connection?.remotePort
        self.certificates = certificates
        self.isChainFromEarlierConnection = isChainFromEarlierConnection
        self.trustDecision = trustDecision
    }
}
