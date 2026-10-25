#if CATWALK_ENABLED && !CATWALK_EXCLUDE_WEBSOCKET
//
//  CWWebSocketRecorder.swift
//  CatWalk
//

import Foundation

/// Turns observed WebSocket task calls into one transaction per connection (source `.webSocket`).
/// Read-only: messages and completion handlers reach the app unchanged.
///
/// Tasks arrive as `NSObject`: the runtime class is not a subclass of `URLSessionWebSocketTask`,
/// so its WebSocket properties are read by key, after checking they exist.
enum CWWebSocketRecorder {

    static func didResume(_ task: NSObject, engine: CWCaptureEngine = .shared) {
        _ = openTransactionID(for: task, engine: engine)
    }

    /// - Returns: the frame id, to mark it if sending fails; `nil` when nothing was recorded.
    @discardableResult
    static func didSend(_ message: NSObject, task: NSObject, engine: CWCaptureEngine = .shared) -> UUID? {
        guard let frame = frame(from: message, direction: .sent, engine: engine) else { return nil }
        return append(frame, task: task, engine: engine) ? frame.id : nil
    }

    static func didFailToSend(frameID: UUID, error: any Error, task: NSObject, engine: CWCaptureEngine = .shared) {
        guard let id = openTransactionID(for: task, engine: engine) else { return }
        let failure = CWTransactionError(error)
        engine.store.update(id: id) { $0.updatingWebSocket { $0.markingFailed(frameID: frameID, error: failure) } }
    }

    static func didReceive(_ message: NSObject, task: NSObject, engine: CWCaptureEngine = .shared) {
        guard let frame = frame(from: message, direction: .received, engine: engine) else { return }
        append(frame, task: task, engine: engine)
    }

    /// Records the ping now; `didReceivePong` follows when the peer answers.
    static func didSendPing(task: NSObject, engine: CWCaptureEngine = .shared) {
        append(CWWebSocketFrame(direction: .sent, kind: .ping), task: task, engine: engine)
    }

    static func didReceivePong(task: NSObject, engine: CWCaptureEngine = .shared) {
        append(CWWebSocketFrame(direction: .received, kind: .pong), task: task, engine: engine)
    }

    /// The app closed the connection (`cancel(with:reason:)`, or `cancel()` with `code == nil`).
    static func didCancel(_ task: NSObject, code: Int?, reason: Data?, engine: CWCaptureEngine = .shared) {
        close(task, code: code, reason: reason, error: nil, engine: engine)
    }

    /// A pending receive failed: the peer closed (close code set) or the connection broke.
    static func didFailToReceive(_ error: any Error, task: NSObject, engine: CWCaptureEngine = .shared) {
        let code = closeCode(of: task)
        if let code {
            close(task, code: code, reason: closeReason(of: task), error: nil, engine: engine)
        } else {
            close(task, code: nil, reason: nil, error: error, engine: engine)
        }
    }
}

// MARK: - Transaction

private extension CWWebSocketRecorder {

    static func isCapturing(_ engine: CWCaptureEngine) -> Bool {
        engine.isRunning && engine.recorder.configuration.captureWebSockets
    }

    /// The row of an open connection, starting it on first use.
    static func openTransactionID(for task: NSObject, engine: CWCaptureEngine) -> UUID? {
        guard isCapturing(engine) else { return nil }
        let record = CWWebSocketTaskRecord.of(task)
        let previous = record.state.withLock { state -> CWWebSocketTaskRecord.Phase in
            let previous = state.phase
            if previous == .idle {
                state.phase = .open
            }
            return previous
        }
        switch previous {
        case .open: return record.id
        case .skipped, .closed: return nil
        case .idle: return begin(task, record: record, engine: engine) ? record.id : nil
        }
    }

    static func begin(_ task: NSObject, record: CWWebSocketTaskRecord, engine: CWCaptureEngine) -> Bool {
        let request = (task as? URLSessionTask)
            .flatMap { $0.originalRequest ?? $0.currentRequest }
            .map(webSocketRequest)
        guard
            let request,
            !engine.isIgnored(host: request.url?.host),
            let begun = engine.recorder.begin(request, body: nil, id: record.id)
        else {
            record.state.withLock { $0.phase = .skipped }
            return false
        }
        engine.store.upsert(begun.asWebSocket())
        return true
    }

    /// - Returns: whether the connection is recorded (the frame may still be dropped if the row was evicted).
    @discardableResult
    static func append(_ frame: CWWebSocketFrame, task: NSObject, engine: CWCaptureEngine) -> Bool {
        guard let id = openTransactionID(for: task, engine: engine) else { return false }
        let recorder = engine.recorder
        let handshake = pendingHandshake(of: task)
        engine.store.update(id: id) { transaction in
            let updated = transaction.updatingWebSocket {
                $0.appending(frame, maxFrames: recorder.configuration.maxFramesPerConnection)
            }
            return handshake.map { recorder.handshake(updated, response: $0) } ?? updated
        }
        return true
    }

    /// The handshake response the first time it is available, then `nil`.
    static func pendingHandshake(of task: NSObject) -> URLResponse? {
        guard let response = (task as? URLSessionTask)?.response else { return nil }
        let isNew = CWWebSocketTaskRecord.of(task).state.withLock { state -> Bool in
            defer { state.hasHandshake = true }
            return !state.hasHandshake
        }
        return isNew ? response : nil
    }

    /// Finishes the row once; later closes (e.g. `cancel()` after `cancel(with:reason:)`) are ignored.
    static func close(_ task: NSObject, code: Int?, reason: Data?, error: (any Error)?, engine: CWCaptureEngine) {
        guard let id = openTransactionID(for: task, engine: engine) else { return }
        let isFirstClose = CWWebSocketTaskRecord.of(task).state.withLock { state -> Bool in
            guard state.phase == .open else { return false }
            state.phase = .closed
            return true
        }
        guard isFirstClose else { return }
        let recorder = engine.recorder
        let response = (task as? URLSessionTask)?.response
        engine.store.update(id: id) { transaction in
            recorder.complete(transaction, response: response, body: nil, error: error)
                .updatingWebSocket { $0.closed(code: code, reason: reason) }
        }
    }
}

// MARK: - Reading runtime objects

private extension CWWebSocketRecorder {

    /// URLSession stores `ws`/`wss` requests as `http`/`https`; show the scheme the app used.
    static func webSocketRequest(_ request: URLRequest) -> URLRequest {
        guard
            let url = request.url,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return request
        }
        components.scheme = scheme == "https" ? "wss" : "ws"
        var copy = request
        copy.url = components.url ?? url
        return copy
    }

    /// `NSURLSessionWebSocketMessage`: `type` 0 = data, 1 = string.
    static func frame(from message: NSObject, direction: CWWebSocketFrame.Direction, engine: CWCaptureEngine) -> CWWebSocketFrame? {
        guard isCapturing(engine) else { return nil }
        let limit = engine.recorder.configuration.maxBodyBytes
        let isText = (value(of: "type", in: message) as? Int) == 1
        let bytes = isText
            ? (value(of: "string", in: message) as? String).map { Data($0.utf8) }
            : value(of: "data", in: message) as? Data
        return CWWebSocketFrame(
            direction: direction,
            kind: isText ? .text : .binary,
            payload: CWBody(capturing: bytes ?? Data(), limit: limit)
        )
    }

    /// `nil` while open (`NSURLSessionWebSocketCloseCodeInvalid` is 0).
    static func closeCode(of task: NSObject) -> Int? {
        (value(of: "closeCode", in: task) as? Int).flatMap { $0 == 0 ? nil : $0 }
    }

    static func closeReason(of task: NSObject) -> Data? {
        value(of: "closeReason", in: task) as? Data
    }

    /// KVC only for getters that exist: a missing key would raise an Objective-C exception.
    static func value(of key: String, in object: NSObject) -> Any? {
        object.responds(to: NSSelectorFromString(key)) ? object.value(forKey: key) : nil
    }
}
#endif
