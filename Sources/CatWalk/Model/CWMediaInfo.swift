#if CATWALK_ENABLED
//
//  CWMediaInfo.swift
//  CatWalk
//

import Foundation

/// What CatWalk knows about an `AVPlayer` request: no headers or bodies, but media-specific fields.
public struct CWMediaInfo: Sendable, Equatable {

    public enum Kind: Sendable, Equatable {
        /// An HLS playlist (iOS 18+).
        case playlist
        /// An HLS media segment (iOS 18+).
        case segment
        case contentKey
        /// One playback session's totals from the player item's access log (before iOS 18).
        case playbackLog
        /// A failure from the player item's error log (before iOS 18).
        case playbackError
    }

    /// Groups the rows of one `AVPlayerItem`.
    public let itemID: UUID

    public let kind: Kind

    /// `vide`, `soun`, `sbtl`… when known.
    public let mediaType: String?

    /// Requested bytes of a segment; `nil` for whole files.
    public let byteRange: Range<Int>?

    public let segmentDuration: TimeInterval?

    public let serverAddress: String?

    public let wasReadFromCache: Bool

    /// Body bytes received, when the system reports them.
    public let bytesReceived: Int64?

    /// Totals of a playback session; only for `.playbackLog`.
    public let playback: Playback?

    public struct Playback: Sendable, Equatable {
        public let transferDuration: TimeInterval
        public let observedBitrate: Double
        public let indicatedBitrate: Double
        public let stallCount: Int
        public let requestCount: Int
        public let durationWatched: TimeInterval
    }

    init(
        itemID: UUID,
        kind: Kind,
        mediaType: String? = nil,
        byteRange: Range<Int>? = nil,
        segmentDuration: TimeInterval? = nil,
        serverAddress: String? = nil,
        wasReadFromCache: Bool = false,
        bytesReceived: Int64? = nil,
        playback: Playback? = nil
    ) {
        self.itemID = itemID
        self.kind = kind
        self.mediaType = mediaType
        self.byteRange = byteRange
        self.segmentDuration = segmentDuration
        self.serverAddress = serverAddress
        self.wasReadFromCache = wasReadFromCache
        self.bytesReceived = bytesReceived
        self.playback = playback
    }
}

extension CWMediaInfo.Kind {

    var title: String {
        switch self {
        case .playlist: "Playlist"
        case .segment: "Segment"
        case .contentKey: "Content key"
        case .playbackLog: "Playback"
        case .playbackError: "Playback error"
        }
    }
}
#endif
