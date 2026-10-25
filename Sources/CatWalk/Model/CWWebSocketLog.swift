#if CATWALK_ENABLED
//
//  CWWebSocketLog.swift
//  CatWalk
//

import Foundation

/// One WebSocket message (or ping/pong) as the app sent or received it.
public struct CWWebSocketFrame: Sendable, Equatable, Identifiable {

    public enum Direction: Sendable, Equatable {
        case sent
        case received
    }

    public enum Kind: Sendable, Equatable {
        case text
        case binary
        case ping
        case pong
    }

    public let id: UUID

    public let direction: Direction

    public let kind: Kind

    /// Capped at `CWConfiguration.maxBodyBytes`; `nil` for ping/pong.
    public let payload: CWBody?

    public let date: Date

    /// Set when sending failed.
    public let error: CWTransactionError?

    init(
        id: UUID = UUID(),
        direction: Direction,
        kind: Kind,
        payload: CWBody? = nil,
        date: Date = Date(),
        error: CWTransactionError? = nil
    ) {
        self.id = id
        self.direction = direction
        self.kind = kind
        self.payload = payload
        self.date = date
        self.error = error
    }

    func failing(with error: CWTransactionError) -> CWWebSocketFrame {
        CWWebSocketFrame(id: id, direction: direction, kind: kind, payload: payload, date: date, error: error)
    }

    func strippingData() -> CWWebSocketFrame {
        CWWebSocketFrame(id: id, direction: direction, kind: kind, payload: payload?.strippingData(), date: date, error: error)
    }
}

/// Messages of one WebSocket connection, newest last. Immutable: changes return a new copy.
public struct CWWebSocketLog: Sendable, Equatable {

    /// At most `CWConfiguration.maxFramesPerConnection`; older frames are dropped first.
    public let frames: [CWWebSocketFrame]

    public let droppedFrameCount: Int

    /// `nil` while open, or when the connection ended without a close frame.
    public let closeCode: Int?

    public let closeReason: String?

    /// Payload bytes held by `frames`, kept up to date so the store budget stays O(1).
    let storedBytes: Int

    init() {
        self.init(frames: [], droppedFrameCount: 0, closeCode: nil, closeReason: nil, storedBytes: 0)
    }

    private init(frames: [CWWebSocketFrame], droppedFrameCount: Int, closeCode: Int?, closeReason: String?, storedBytes: Int) {
        self.frames = frames
        self.droppedFrameCount = droppedFrameCount
        self.closeCode = closeCode
        self.closeReason = closeReason
        self.storedBytes = storedBytes
    }

    public var sentCount: Int {
        frames.count(where: { $0.direction == .sent })
    }

    public var receivedCount: Int {
        frames.count(where: { $0.direction == .received })
    }

    /// O(frames): copies the log, then drops the oldest frames over `maxFrames`.
    func appending(_ frame: CWWebSocketFrame, maxFrames: Int) -> CWWebSocketLog {
        let all = frames + [frame]
        let overflow = max(0, all.count - max(1, maxFrames))
        let dropped = all.prefix(overflow)
        return copy(
            frames: Array(all.dropFirst(overflow)),
            droppedFrameCount: droppedFrameCount + overflow,
            storedBytes: storedBytes + Self.bytes(of: frame) - dropped.reduce(0) { $0 + Self.bytes(of: $1) }
        )
    }

    func markingFailed(frameID: UUID, error: CWTransactionError) -> CWWebSocketLog {
        copy(frames: frames.map { $0.id == frameID ? $0.failing(with: error) : $0 })
    }

    func closed(code: Int?, reason: Data?) -> CWWebSocketLog {
        CWWebSocketLog(
            frames: frames,
            droppedFrameCount: droppedFrameCount,
            closeCode: code,
            closeReason: reason.flatMap { $0.isEmpty ? nil : String(data: $0, encoding: .utf8) },
            storedBytes: storedBytes
        )
    }

    func strippingData() -> CWWebSocketLog {
        copy(frames: frames.map { $0.strippingData() }, storedBytes: 0)
    }

    private func copy(frames: [CWWebSocketFrame], droppedFrameCount: Int? = nil, storedBytes: Int? = nil) -> CWWebSocketLog {
        CWWebSocketLog(
            frames: frames,
            droppedFrameCount: droppedFrameCount ?? self.droppedFrameCount,
            closeCode: closeCode,
            closeReason: closeReason,
            storedBytes: storedBytes ?? self.storedBytes
        )
    }

    private static func bytes(of frame: CWWebSocketFrame) -> Int {
        frame.payload?.data.count ?? 0
    }
}

extension CWWebSocketLog {

    /// RFC 6455 §7.4.1 names; 3000–4999 are defined by libraries and apps.
    static func closeCodeName(_ code: Int) -> String {
        switch code {
        case 1000: "Normal closure"
        case 1001: "Going away"
        case 1002: "Protocol error"
        case 1003: "Unsupported data"
        case 1005: "No status received"
        case 1006: "Abnormal closure"
        case 1007: "Invalid payload"
        case 1008: "Policy violation"
        case 1009: "Message too big"
        case 1010: "Missing extension"
        case 1011: "Internal server error"
        case 1015: "TLS handshake failure"
        case 3000..<5000: "Application code"
        default: "Unknown"
        }
    }
}
#endif
