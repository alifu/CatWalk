#if CATWALK_ENABLED
//
//  CWBody.swift
//  CatWalk
//

import Foundation

/// A captured HTTP body, capped at `CWConfiguration.maxBodyBytes`.
///
/// Bodies of `diskThreshold` bytes or more live in a temporary file, not on the heap; `data` reads
/// the file back on demand. The file is deleted when the last copy of the body is released.
public struct CWBody: Sendable, Equatable {

    /// Bodies at least this large are written to disk. Smaller ones stay in memory: a file each would cost more than the bytes.
    static let diskThreshold = 4 * 1024

    private enum Storage: Sendable {
        case memory(Data)
        case file(CWBodyFile)
    }

    private let storage: Storage

    /// Number of captured bytes (at most the configured limit); reading it never touches the disk.
    public let storedBytes: Int

    /// Size of the full body as sent or received.
    public let totalBytes: Int

    /// Captured bytes. O(size) for a body on disk, because it reads the file; empty if the file is gone.
    public var data: Data {
        switch storage {
        case let .memory(data): data
        case let .file(file): file.read()
        }
    }

    /// The backing file, if the body is on disk.
    var fileURL: URL? {
        if case let .file(file) = storage { file.url } else { nil }
    }

    public var isTruncated: Bool {
        totalBytes > storedBytes
    }

    init(data: Data, totalBytes: Int) {
        self.storedBytes = data.count
        self.totalBytes = totalBytes
        if data.count >= Self.diskThreshold, let file = CWBodyFile(writing: data) {
            storage = .file(file)
        } else {
            storage = .memory(data)
        }
    }

    private init(storage: Storage, storedBytes: Int, totalBytes: Int) {
        self.storage = storage
        self.storedBytes = storedBytes
        self.totalBytes = totalBytes
    }

    /// Same size, no bytes: what remains after a memory purge. A body on disk is not in memory, so it is kept.
    func strippingData() -> CWBody {
        if case .file = storage { return self }
        return CWBody(storage: .memory(Data()), storedBytes: 0, totalBytes: totalBytes)
    }

    /// O(min(size, limit)): copies only the kept prefix; shares storage when under the limit.
    init(capturing data: Data, limit: Int) {
        let kept = data.count <= limit ? data : Data(data.prefix(max(0, limit)))
        self.init(data: kept, totalBytes: data.count)
    }

    public static func == (lhs: CWBody, rhs: CWBody) -> Bool {
        lhs.totalBytes == rhs.totalBytes && lhs.storedBytes == rhs.storedBytes && lhs.data == rhs.data
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

    /// Moves the collected bytes to disk when they are large enough.
    var body: CWBody? {
        totalBytes == 0 ? nil : CWBody(data: data, totalBytes: totalBytes)
    }
}
#endif
