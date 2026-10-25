//
//  WebSocketChat.swift
//  DemoSwiftUI
//

import Foundation
import os

/// Talks to a public echo server with `URLSessionWebSocketTask`, which `URLProtocol` never sees.
/// CatWalk shows the connection with a "WS" chip and every message in its Messages tab.
final class WebSocketChat: @unchecked Sendable {

    static let shared = WebSocketChat()

    private static let logger = Logger(subsystem: "CatWalk.DemoSwiftUI", category: "websocket")
    private static let echoURL = URL(string: "wss://ws.postman-echo.com/raw")!

    /// Sends a text and a JSON message, reads the echoes, pings, then closes.
    /// (This echo server drops the connection on binary messages.)
    func run() {
        Task {
            let task = URLSession.shared.webSocketTask(with: Self.echoURL)
            task.resume()
            do {
                for message: URLSessionWebSocketTask.Message in [
                    .string("Hello from CatWalk"),
                    .string(#"{"type":"greeting","user":{"id":1,"name":"Cat"}}"#),
                ] {
                    try await task.send(message)
                    _ = try await task.receive()
                }
                task.sendPing { error in
                    if let error { Self.logger.error("Ping failed: \(error.localizedDescription)") }
                    task.cancel(with: .normalClosure, reason: Data("done".utf8))
                }
            } catch {
                Self.logger.error("WebSocket demo failed: \(error.localizedDescription)")
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }
}
