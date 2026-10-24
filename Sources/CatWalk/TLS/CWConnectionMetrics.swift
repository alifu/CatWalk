#if CATWALK_ENABLED
//
//  CWConnectionMetrics.swift
//  CatWalk
//

import Foundation

/// Sendable copy of the parts of `URLSessionTaskMetrics` CatWalk keeps.
struct CWConnectionMetrics: Sendable, Equatable {
    var tlsProtocolVersion: UInt16?
    var tlsCipherSuite: UInt16?
    var isProxyConnection = false
    var isReusedConnection = false
    var remoteAddress: String?
    var remotePort: Int?
}

extension CWConnectionMetrics {

    /// Uses the last transaction: the one that produced the delivered response.
    init?(_ metrics: URLSessionTaskMetrics) {
        guard let last = metrics.transactionMetrics.last else { return nil }
        self.init(
            tlsProtocolVersion: last.negotiatedTLSProtocolVersion?.rawValue,
            tlsCipherSuite: last.negotiatedTLSCipherSuite?.rawValue,
            isProxyConnection: last.isProxyConnection,
            isReusedConnection: last.isReusedConnection,
            remoteAddress: last.remoteAddress,
            remotePort: last.remotePort
        )
    }
}
#endif
