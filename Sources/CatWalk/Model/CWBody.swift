#if CATWALK_ENABLED
//
//  CWBody.swift
//  CatWalk
//

import Foundation

/// A captured HTTP body, capped at `CWConfiguration.maxBodyBytes`.
public struct CWBody: Sendable, Equatable {

    /// Captured bytes (at most the configured limit).
    public let data: Data

    /// Size of the full body as sent or received.
    public let totalBytes: Int

    public var isTruncated: Bool {
        totalBytes > data.count
    }

    init(data: Data, totalBytes: Int) {
        self.data = data
        self.totalBytes = totalBytes
    }

    /// Same size, no bytes: what remains after a memory purge.
    func strippingData() -> CWBody {
        CWBody(data: Data(), totalBytes: totalBytes)
    }

    /// O(min(size, limit)): copies only the kept prefix; shares storage when under the limit.
    init(capturing data: Data, limit: Int) {
        let kept = data.count <= limit ? data : Data(data.prefix(max(0, limit)))
        self.init(data: kept, totalBytes: data.count)
    }
}

/// Collects streamed response chunks without holding more than `limit` bytes.
struct CWBodyAccumulator: Sendable {

    let limit: Int

    private var data = Data()
    private var totalBytes = 0

    init(limit: Int) {
        self.limit = max(0, limit)
    }

    /// O(min(chunk, remaining capacity)).
    mutating func append(_ chunk: Data) {
        totalBytes += chunk.count

        let remaining = limit - data.count
        guard remaining > 0 else { return }

        data.append(chunk.prefix(remaining))
    }

    var body: CWBody? {
        totalBytes == 0 ? nil : CWBody(data: data, totalBytes: totalBytes)
    }
}
#endif
