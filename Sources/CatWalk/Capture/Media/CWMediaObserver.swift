#if CATWALK_ENABLED && !CATWALK_EXCLUDE_MEDIA
//
//  CWMediaObserver.swift
//  CatWalk
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import ObjectiveC
import os

/// `AVPlayer` loads media in the media server, out of `URLProtocol`'s reach, so CatWalk reads what
/// AVFoundation reports about each `AVPlayerItem`:
///
/// - iOS 18+: AVMetrics events for HLS playlist, segment and content-key requests, each with the
///   request, response and `URLSessionTaskMetrics`. See `CWMediaPlayerObservation`.
/// - before iOS 18: the item's access and error logs, one row per playback session.
enum CWMediaObserver {

    private static let logger = Logger(subsystem: "com.catwalk", category: "media")

    private static let installation: Void = {
        if #available(iOS 18, macOS 15, tvOS 18, visionOS 2, *) {
            CWMediaPlayerObservation.install()
        } else {
            let center = NotificationCenter.default
            center.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: nil, queue: nil) { didLog($0, errors: false) }
            center.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: nil, queue: nil) { didLog($0, errors: true) }
        }
    }()

    /// Idempotent; the observers do nothing while capture is stopped or `captureMedia` is off.
    static func install() {
        _ = installation
    }

    static func warn(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    // MARK: Logs (before iOS 18)

    static func didLog(_ notification: Notification, errors: Bool, engine: CWCaptureEngine = .shared) {
        guard
            engine.isRunning, engine.recorder.configuration.captureMedia,
            let item = notification.object as? AVPlayerItem
        else {
            return
        }
        let record = CWMediaItemRecord.of(item)
        if errors {
            recordErrors(of: item, record: record, engine: engine)
        } else {
            recordAccessLog(of: item, record: record, engine: engine)
        }
    }

    static func recordAccessLog(of item: AVPlayerItem, record: CWMediaItemRecord, engine: CWCaptureEngine) {
        for event in item.accessLog()?.events ?? [] {
            guard let uri = event.uri.flatMap(URL.init(string:)) else { continue }
            let sample = CWMediaLogSample(
                uri: uri,
                serverAddress: event.serverAddress,
                startDate: event.playbackStartDate ?? Date(),
                bytesTransferred: max(0, event.numberOfBytesTransferred),
                playback: CWMediaInfo.Playback(
                    transferDuration: max(0, event.transferDuration),
                    observedBitrate: event.observedBitrate,
                    indicatedBitrate: event.indicatedBitrate,
                    stallCount: max(0, event.numberOfStalls),
                    requestCount: max(0, event.numberOfMediaRequests),
                    durationWatched: max(0, event.durationWatched)
                )
            )
            CWMediaRecorder.record(sample, itemID: record.itemID, record: record, engine: engine)
        }
    }

    static func recordErrors(of item: AVPlayerItem, record: CWMediaItemRecord, engine: CWCaptureEngine) {
        let events = item.errorLog()?.events ?? []
        let processed = record.state.withLock { state -> Int in
            defer { state.processedErrorCount = events.count }
            return state.processedErrorCount
        }
        for event in events.dropFirst(processed) {
            let sample = CWMediaErrorSample(
                uri: event.uri.flatMap(URL.init(string:)),
                serverAddress: event.serverAddress,
                date: event.date ?? Date(),
                statusCode: event.errorStatusCode,
                domain: event.errorDomain,
                comment: event.errorComment
            )
            CWMediaRecorder.record(sample, itemID: record.itemID, engine: engine)
        }
    }
}
#endif
#endif
