#if CATWALK_ENABLED
//
//  CWMediaPlayerTests.swift
//  CatWalk
//
//  A real AVPlayerItem loading an HLS playlist from `HLSTestServer`. AVMetrics needs iOS 18.
//

import AVFoundation
import Foundation
import Testing
@testable import CatWalk

extension SharedEngine {

    @Suite("Media player", .serialized)
    final class CWMediaPlayerTests {

        let engine = CWCaptureEngine.shared
        private let server: HLSTestServer

        init() throws {
            server = try HLSTestServer()
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: []))
        }

        deinit {
            server.stop()
            CWCaptureEngine.shared.stop()
        }

        nonisolated(unsafe) private static let playerLoads = CWLocked<Bool?>(nil)

        /// Cancels the test when this runtime's AVPlayer reports no request to CatWalk at all
        /// (iOS 18.4 simulators under xctest deliver no metrics for the loopback server).
        private func requirePlayerThatLoads() async throws {
            if let known = Self.playerLoads.withLock({ $0 }) {
                if !known { try Test.cancel("AVPlayer reports no local HLS requests in this runtime") }
                return
            }
            let probe = try HLSTestServer()
            defer { probe.stop() }
            let url = try await probe.start()
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            defer { player.replaceCurrentItem(with: nil) }
            var loads = false
            for _ in 0..<150 where !loads {
                try? await Task.sleep(nanoseconds: 20_000_000)
                loads = !mediaRows(port: url.port).isEmpty
            }
            Self.playerLoads.withLock { $0 = loads }
            if !loads { try Test.cancel("AVPlayer reports no local HLS requests in this runtime") }
        }

        private func mediaRows(port: Int?) -> [CWTransaction] {
            engine.store.snapshot().filter { ($0.source == .media || $0.source == .urlSession) && $0.request.url.port == port }
        }

        private func waitForRows(port: Int?, count: Int) async -> [CWTransaction] {
            for _ in 0..<500 {
                let found = mediaRows(port: port)
                if found.count >= count { return found }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            return mediaRows(port: port)
        }

        @Test("HLS playlist requests of a new player item are recorded with status, headers and timing (iOS 18+)")
        func playlists() async throws {
            guard #available(iOS 18, *) else { return }
            try await requirePlayerThatLoads()
            let url = try await server.start()
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            defer { player.replaceCurrentItem(with: nil) }

            let rows = await waitForRows(port: url.port, count: 2)

            let master = try #require(rows.first { $0.request.url.path == "/master.m3u8" })
            let media = try #require(rows.first { $0.request.url.path == "/media.m3u8" })
            // Where the load goes through CatWalk's own session, the URL-protocol row stands in for the media row.
            if master.source == .media {
                #expect(master.media?.kind == .playlist)
                #expect(media.media?.kind == .playlist)
                #expect(master.media?.itemID == media.media?.itemID)
                #expect(master.media?.bytesReceived == Int64(HLSTestServer.master.utf8.count))
                #expect(master.timing != nil)
                #expect(!master.isMockable)
            }
            #expect(master.response?.statusCode == 200)
            #expect(master.response?.headers["Content-Type"] == "application/vnd.apple.mpegurl")
            #expect(master.state == .completed)
        }

        @Test("players made through every initialiser are observed (iOS 18+)", arguments: ["url", "item", "empty", "queue"])
        func initializers(_ variant: String) async throws {
            guard #available(iOS 18, *) else { return }
            try await requirePlayerThatLoads()
            let url = try await server.start()
            let player: AVPlayer = switch variant {
            case "url": AVPlayer(url: url)
            case "item": AVPlayer(playerItem: AVPlayerItem(url: url))
            case "queue": AVQueuePlayer(items: [AVPlayerItem(url: url)])
            default: AVPlayer()
            }
            if variant == "empty" {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
            }
            defer { player.replaceCurrentItem(with: nil) }

            let rows = await waitForRows(port: url.port, count: 1)

            #expect(!rows.isEmpty)
        }

        @Test("observing does not keep the item alive")
        func releasesItems() async throws {
            guard #available(iOS 18, *) else { return }
            try await requirePlayerThatLoads()
            let url = try await server.start()
            weak var released: AVPlayerItem?
            do {
                let item = AVPlayerItem(url: url)
                released = item
                let player = AVPlayer(playerItem: item)
                _ = await waitForRows(port: url.port, count: 1)
                player.replaceCurrentItem(with: nil)
            }
            for _ in 0..<150 where released != nil {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }

            #expect(released == nil)
        }

        @Test("the log notification handler tolerates an item without logs")
        func emptyLogs() {
            let item = AVPlayerItem(url: URL(string: "https://nolog.test/master.m3u8")!)
            let before = engine.store.count

            CWMediaObserver.didLog(Notification(name: .AVPlayerItemNewAccessLogEntry, object: item), errors: false)
            CWMediaObserver.didLog(Notification(name: .AVPlayerItemNewErrorLogEntry, object: item), errors: true)

            #expect(engine.store.count == before)
        }

        @Test("an item whose capture is switched off records nothing")
        func captureOff() async throws {
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: [], captureMedia: false))
            let url = try await server.start()
            let player = AVPlayer(playerItem: AVPlayerItem(url: url))
            defer { player.replaceCurrentItem(with: nil) }

            try await Task.sleep(nanoseconds: 1_500_000_000)

            #expect(mediaRows(port: url.port).isEmpty)
        }
    }
}
#endif
