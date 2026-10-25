#if CATWALK_ENABLED && !CATWALK_EXCLUDE_BACKGROUND
//
//  CWBackgroundRecorder.swift
//  CatWalk
//

import Foundation
import os

/// Turns observed background-session callbacks into transactions (source `.backgroundSession`).
/// Read-only: nothing here changes what the app's delegate receives.
enum CWBackgroundRecorder {

    private static let logger = Logger(subsystem: "com.catwalk", category: "background")

    static func didCollect(_ metrics: URLSessionTaskMetrics, task: URLSessionTask, engine: CWCaptureEngine = .shared) {
        guard engine.isRunning, let connection = CWConnectionMetrics(metrics) else { return }
        let record = CWBackgroundTaskRecord.of(task, limit: engine.recorder.configuration.maxBodyBytes)
        let isRecorded = record.state.withLock { state in
            state.metrics = connection
            return state.isRecorded
        }
        // Metrics after completion (rare): fill in the stored row, never erase it.
        if isRecorded, let url = task.originalRequest?.url {
            engine.store.update(id: record.id) {
                $0.withConnectionDetails(tls: engine.tlsInfo(for: url, connection: connection), timing: connection.timing)
            }
        }
    }

    /// Must run **before** the app's delegate: the system deletes the file once that call returns.
    static func didFinishDownloading(_ task: URLSessionTask, to location: URL, engine: CWCaptureEngine = .shared) {
        guard engine.isRunning else { return }
        let limit = engine.recorder.configuration.maxBodyBytes
        let body = readPrefix(of: location, limit: limit)
        CWBackgroundTaskRecord.of(task, limit: limit).state.withLock { $0.downloadedBody = body }
    }

    static func didReceive(_ data: Data, task: URLSessionTask, engine: CWCaptureEngine = .shared) {
        guard engine.isRunning else { return }
        CWBackgroundTaskRecord.of(task, limit: engine.recorder.configuration.maxBodyBytes)
            .state.withLock { $0.receivedBody.append(data) }
    }

    static func didCreateUpload(_ task: URLSessionTask, fromFile file: URL, engine: CWCaptureEngine = .shared) {
        CWBackgroundTaskRecord.of(task, limit: engine.recorder.configuration.maxBodyBytes)
            .state.withLock { $0.uploadFile = file }
    }

    /// Records the finished task once. O(min(body, maxBodyBytes)) for the upload prefix.
    static func didComplete(_ task: URLSessionTask, error: (any Error)?, engine: CWCaptureEngine = .shared) {
        guard
            engine.isRunning,
            let request = task.originalRequest ?? task.currentRequest,
            let url = request.url,
            !engine.isIgnored(host: url.host)
        else {
            return
        }
        let recorder = engine.recorder
        let record = CWBackgroundTaskRecord.of(task, limit: recorder.configuration.maxBodyBytes)
        let snapshot = record.state.withLock { state -> State? in
            guard !state.isRecorded else { return nil }
            state.isRecorded = true
            return State(state)
        }
        guard let snapshot else { return }

        let timing = snapshot.metrics?.timing
        let start = timing?.fetchStart ?? timing?.total?.start ?? Date()
        let requestBody = request.httpBody.map { CWBody(capturing: $0, limit: recorder.configuration.maxBodyBytes) }
            ?? snapshot.uploadFile.flatMap { readPrefix(of: $0, limit: recorder.configuration.maxBodyBytes) }

        guard let begun = recorder.begin(request, capturedBody: requestBody, id: record.id, at: start) else { return }
        let finished = recorder.complete(
            begun,
            response: task.response,
            body: snapshot.downloadedBody ?? snapshot.receivedBody,
            error: error,
            tls: engine.tlsInfo(for: url, connection: snapshot.metrics),
            timing: timing,
            at: timing?.total?.end ?? Date()
        )
        engine.store.upsert(finished.from(.backgroundSession))
    }

    private struct State {
        let metrics: CWConnectionMetrics?
        let downloadedBody: CWBody?
        let receivedBody: CWBody?
        let uploadFile: URL?

        init(_ state: CWBackgroundTaskRecord.State) {
            metrics = state.metrics
            downloadedBody = state.downloadedBody
            receivedBody = state.receivedBody.body
            uploadFile = state.uploadFile
        }
    }

    /// First `limit` bytes plus the file size; `nil` when the file cannot be read.
    static func readPrefix(of file: URL, limit: Int) -> CWBody? {
        do {
            let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size > 0 else { return nil }
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            let prefix = try handle.read(upToCount: max(0, limit)) ?? Data()
            return CWBody(data: prefix, totalBytes: size)
        } catch {
            logger.error("Could not read \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
#endif
