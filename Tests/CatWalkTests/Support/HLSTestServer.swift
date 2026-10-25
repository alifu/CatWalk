#if CATWALK_ENABLED
//
//  HLSTestServer.swift
//  CatWalk
//

import Foundation
import Network
@testable import CatWalk

/// Loopback HTTP server with a master playlist (`/master.m3u8`), one media playlist (`/media.m3u8`)
/// and no segments (`/seg0.ts` answers 404), enough for AVFoundation to request playlists.
final class HLSTestServer: @unchecked Sendable {

    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.catwalk.tests.hls")
    private let paths = CWLocked<[String]>([])

    /// Paths requested so far, in order.
    var requestedPaths: [String] {
        paths.withLock { $0 }
    }

    static let master = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
    media.m3u8
    """

    static let media = """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:4
    #EXT-X-MEDIA-SEQUENCE:0
    #EXTINF:4.0,
    seg0.ts
    #EXT-X-ENDLIST
    """

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [queue, paths] connection in
            connection.start(queue: queue)
            Self.serve(connection, paths: paths)
        }
    }

    /// Starts listening and returns the master playlist URL (`http://127.0.0.1:<port>/master.m3u8`).
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
        return URL(string: "http://127.0.0.1:\(port)/master.m3u8")!
    }

    func stop() {
        listener.cancel()
    }

    private static func serve(_ connection: NWConnection, paths: CWLocked<[String]>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
            guard error == nil, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            paths.withLock { $0.append(path) }
            let (status, body): (String, String) = switch path {
            case "/master.m3u8": ("200 OK", master)
            case "/media.m3u8": ("200 OK", media)
            default: ("404 Not Found", "missing")
            }
            let type = path.hasSuffix(".m3u8") ? "application/vnd.apple.mpegurl" : "text/plain"
            let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
            connection.send(content: Data((head + body).utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
#endif
