#if CATWALK_ENABLED && !CATWALK_EXCLUDE_MEDIA
//
//  CWMediaSummary.swift
//  CatWalk
//

import SwiftUI

/// Media fields of an `AVPlayer` request, for the Overview tab.
struct CWMediaSummary: View {

    let media: CWMediaInfo

    var body: some View {
        CWKeyValueRow(name: "Kind", value: media.kind.title)
        CWKeyValueRow(name: "Player item", value: String(media.itemID.uuidString.prefix(8)))
        if let type = media.mediaType {
            CWKeyValueRow(name: "Media type", value: type)
        }
        if let range = media.byteRange {
            CWKeyValueRow(name: "Byte range", value: "\(range.lowerBound)–\(range.upperBound - 1)")
        }
        if let duration = media.segmentDuration {
            CWKeyValueRow(name: "Segment duration", value: CWFormat.duration(duration))
        }
        if let bytes = media.bytesReceived {
            CWKeyValueRow(name: "Received", value: CWFormat.bytes(Int(bytes)))
        }
        if let address = media.serverAddress {
            CWKeyValueRow(name: "Server", value: address)
        }
        if media.wasReadFromCache {
            CWKeyValueRow(name: "Cache", value: "Read from cache")
        }
        if let playback = media.playback {
            CWKeyValueRow(name: "Requests", value: "\(playback.requestCount)")
            CWKeyValueRow(name: "Stalls", value: "\(playback.stallCount)")
            CWKeyValueRow(name: "Watched", value: CWFormat.duration(playback.durationWatched))
            CWKeyValueRow(name: "Transfer time", value: CWFormat.duration(playback.transferDuration))
            CWKeyValueRow(name: "Bitrate", value: "\(bitrate(playback.observedBitrate)) observed · \(bitrate(playback.indicatedBitrate)) indicated")
        }
    }

    private func bitrate(_ bitsPerSecond: Double) -> String {
        bitsPerSecond > 0 ? String(format: "%.0f kbps", bitsPerSecond / 1000) : "—"
    }
}
#endif
