#if CATWALK_ENABLED
//
//  CWMediaRecorder.swift
//  CatWalk
//

import Foundation

/// Turns media samples into transactions (source `.media`). Read-only: nothing here touches playback.
enum CWMediaRecorder {

    static let errorDomain = "CatWalk.Media"

    private static func isCapturing(_ engine: CWCaptureEngine) -> Bool {
        engine.isRunning && engine.recorder.configuration.captureMedia
    }

    // MARK: AVMetrics (iOS 18+)

    static func record(_ sample: CWMediaRequestSample, itemID: UUID, record: CWMediaItemRecord, engine: CWCaptureEngine = .shared) {
        guard
            isCapturing(engine), !engine.isIgnored(host: sample.url.host),
            !hasURLProtocolTwin(sample, in: engine.store)
        else {
            return
        }
        let limit = engine.recorder.configuration.maxMediaRequestsPerItem
        let isWithinLimit = record.state.withLock { state -> Bool in
            guard state.requestCount < limit else {
                state.skippedCount += 1
                return false
            }
            state.requestCount += 1
            return true
        }
        guard isWithinLimit else { return }
        engine.store.upsert(transaction(for: sample, itemID: itemID, engine: engine))
    }

    /// Within this window of the media event's start, a row for the same URL is the same request.
    static let twinWindow: TimeInterval = 30

    /// When AVFoundation loads through a session CatWalk already injects into, `CWURLProtocol` has
    /// captured the request completely (status, headers, body, timing). The media row would only repeat it.
    /// O(n) over the stored transactions.
    static func hasURLProtocolTwin(_ sample: CWMediaRequestSample, in store: CWTransactionStore) -> Bool {
        store.snapshot().contains { transaction in
            transaction.source == .urlSession
                && transaction.request.url.absoluteString == sample.url.absoluteString
                && abs(transaction.startDate.timeIntervalSince(sample.requestStart)) <= twinWindow
        }
    }

    static func transaction(for sample: CWMediaRequestSample, itemID: UUID, engine: CWCaptureEngine) -> CWTransaction {
        let recorder = engine.recorder
        let last = sample.metrics?.transactionMetrics.last
        // The metrics carry the request as sent (headers) and the response (status, headers).
        let request = last?.request ?? URLRequest(url: sample.url)
        let connection = sample.metrics.flatMap(CWConnectionMetrics.init)
        let begun = recorder.begin(request, body: nil, at: sample.requestStart)
            ?? recorder.begin(URLRequest(url: sample.url), body: nil, at: sample.requestStart)!
        let finished = recorder.complete(
            begun,
            response: last?.response,
            body: nil,
            error: sample.error,
            tls: engine.tlsInfo(for: sample.url, connection: connection),
            timing: connection?.timing,
            at: sample.responseEnd
        )
        return finished.asMedia(CWMediaInfo(
            itemID: itemID,
            kind: sample.kind,
            mediaType: sample.mediaType,
            byteRange: sample.byteRange,
            segmentDuration: sample.segmentDuration,
            serverAddress: sample.serverAddress,
            wasReadFromCache: sample.wasReadFromCache,
            bytesReceived: last.map(\.countOfResponseBodyBytesReceived)
        ))
    }

    // MARK: Access and error logs (before iOS 18)

    /// One row per playback session (URI), updated as the log grows.
    static func record(_ sample: CWMediaLogSample, itemID: UUID, record: CWMediaItemRecord, engine: CWCaptureEngine = .shared) {
        guard isCapturing(engine), !engine.isIgnored(host: sample.uri.host) else { return }
        let key = sample.uri.absoluteString
        let rowID = record.state.withLock { state -> UUID in
            if let existing = state.playbackRowIDs[key] { return existing }
            let created = UUID()
            state.playbackRowIDs[key] = created
            return created
        }
        let recorder = engine.recorder
        let info = CWMediaInfo(
            itemID: itemID,
            kind: .playbackLog,
            serverAddress: sample.serverAddress,
            bytesReceived: sample.bytesTransferred,
            playback: sample.playback
        )
        let end = sample.startDate.addingTimeInterval(max(sample.playback.transferDuration, 0))
        guard let begun = recorder.begin(URLRequest(url: sample.uri), body: nil, id: rowID, at: sample.startDate) else { return }
        engine.store.upsert(recorder.complete(begun, response: nil, body: nil, error: nil, at: end).asMedia(info))
    }

    static func record(_ sample: CWMediaErrorSample, itemID: UUID, engine: CWCaptureEngine = .shared) {
        guard isCapturing(engine), let url = sample.uri, !engine.isIgnored(host: url.host) else { return }
        let recorder = engine.recorder
        let failure = NSError(
            domain: sample.domain.isEmpty ? errorDomain : sample.domain,
            code: sample.statusCode,
            userInfo: [NSLocalizedDescriptionKey: sample.comment ?? "Playback error \(sample.statusCode)"]
        )
        guard let begun = recorder.begin(URLRequest(url: url), body: nil, at: sample.date) else { return }
        let info = CWMediaInfo(itemID: itemID, kind: .playbackError, serverAddress: sample.serverAddress)
        engine.store.upsert(recorder.complete(begun, response: nil, body: nil, error: failure, at: sample.date).asMedia(info))
    }
}
#endif
