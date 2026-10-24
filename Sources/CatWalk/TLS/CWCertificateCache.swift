//
//  CWCertificateCache.swift
//  CatWalk
//

import Foundation

/// Last chain seen per `host:port`, so loads on reused connections (no handshake) still show it.
final class CWCertificateCache: Sendable {

    static let defaultLimit = 64

    private let limit: Int
    private let chains = CWLocked<[String: [CWCertificate]]>([:])

    init(limit: Int = CWCertificateCache.defaultLimit) {
        self.limit = max(1, limit)
    }

    static func key(host: String, port: Int) -> String {
        "\(host.lowercased()):\(port)"
    }

    static func key(for url: URL) -> String? {
        guard let host = url.host else { return nil }
        let port = url.port ?? (url.scheme?.lowercased() == "http" ? 80 : 443)
        return key(host: host, port: port)
    }

    /// O(1). Bounded: a full cache is emptied first rather than tracking recency.
    func store(_ chain: [CWCertificate], for key: String) {
        guard !chain.isEmpty else { return }
        chains.withLock { chains in
            if chains[key] == nil, chains.count >= limit {
                chains.removeAll(keepingCapacity: true)
            }
            chains[key] = chain
        }
    }

    func chain(for key: String) -> [CWCertificate]? {
        chains.withLock { $0[key] }
    }

    func removeAll() {
        chains.withLock { $0.removeAll() }
    }
}
