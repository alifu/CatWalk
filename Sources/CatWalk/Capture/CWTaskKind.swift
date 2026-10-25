#if CATWALK_ENABLED
//
//  CWTaskKind.swift
//  CatWalk
//

import Foundation

enum CWTaskKind {

    /// By behaviour, not class: the runtime class is not a `URLSessionWebSocketTask` subclass.
    /// Needed even when WebSocket capture is compiled out, because the `URLProtocol` must not load these tasks.
    static func isWebSocket(_ task: URLSessionTask) -> Bool {
        task.responds(to: NSSelectorFromString("sendPingWithPongReceiveHandler:"))
    }
}
#endif
