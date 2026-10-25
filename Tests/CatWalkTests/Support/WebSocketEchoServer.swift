#if CATWALK_ENABLED
//
//  WebSocketEchoServer.swift
//  CatWalk
//

import Foundation
import Network
@testable import CatWalk

/// Loopback WebSocket server that echoes text and binary messages and answers pings.
/// Sending the text `close-me` makes it close with code 4000 and reason "server bye".
final class WebSocketEchoServer: @unchecked Sendable {

    static let closeCommand = "close-me"
    static let closeCode: UInt16 = 4000
    static let closeReason = "server bye"

    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.catwalk.tests.echo")

    init() throws {
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        listener = try NWListener(using: parameters, on: .any)
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            Self.serve(connection)
        }
    }

    /// Starts listening and returns the `ws://127.0.0.1:<port>` URL.
    func start() async throws -> URL {
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            let resumed = LockedFlag()
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    if resumed.claim() { continuation.resume(returning: listener.port?.rawValue ?? 0) }
                case let .failed(error):
                    if resumed.claim() { continuation.resume(throwing: error) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
        return URL(string: "ws://127.0.0.1:\(port)/socket")!
    }

    func stop() {
        listener.cancel()
    }

    private static func serve(_ connection: NWConnection) {
        connection.receiveMessage { content, context, _, error in
            guard
                error == nil,
                let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            else {
                connection.cancel()
                return
            }
            switch metadata.opcode {
            case .text where content == Data(closeCommand.utf8):
                close(connection)
                return
            case .text, .binary:
                send(content ?? Data(), opcode: metadata.opcode, on: connection)
            case .close:
                connection.cancel()
                return
            default:
                break
            }
            serve(connection)
        }
    }

    private static func send(_ data: Data, opcode: NWProtocolWebSocket.Opcode, on connection: NWConnection) {
        let context = NWConnection.ContentContext(identifier: "echo", metadata: [NWProtocolWebSocket.Metadata(opcode: opcode)])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private static func close(_ connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = .privateCode(closeCode)
        let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
        connection.send(content: Data(closeReason.utf8), contentContext: context, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

/// One-shot flag so a continuation is resumed once.
final class LockedFlag: Sendable {

    private let flag = CWLocked(false)

    func claim() -> Bool {
        flag.withLock { isSet in
            defer { isSet = true }
            return !isSet
        }
    }
}
#endif
