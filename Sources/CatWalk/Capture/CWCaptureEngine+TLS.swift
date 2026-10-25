#if CATWALK_ENABLED
//
//  CWCaptureEngine+TLS.swift
//  CatWalk
//

import Foundation

extension CWCaptureEngine {

    /// TLS details for a transfer CatWalk did not see the handshake of (background sessions, media):
    /// the connection fields from its metrics, and the chain from an earlier foreground connection
    /// to the same host, when there was one.
    func tlsInfo(for url: URL, connection: CWConnectionMetrics?) -> CWTLSInfo? {
        guard url.scheme?.lowercased() == "https" else { return nil }
        let chain = CWCertificateCache.key(for: url).flatMap(certificates.chain(for:))
        guard connection != nil || chain != nil else { return nil }
        return CWTLSInfo(
            connection: connection,
            certificates: chain ?? [],
            isChainFromEarlierConnection: chain != nil,
            trustDecision: nil
        )
    }
}
#endif
