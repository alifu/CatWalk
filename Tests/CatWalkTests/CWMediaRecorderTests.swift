#if CATWALK_ENABLED
//
//  CWMediaRecorderTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

extension SharedEngine {

    @Suite("Media recorder", .serialized)
    final class CWMediaRecorderTests {

        let engine = CWCaptureEngine.shared
        private let itemID = UUID()
        private let record = CWMediaItemRecord()

        init() {
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: []))
        }

        deinit {
            CWCaptureEngine.shared.stop()
        }

        private func rows(host: String) -> [CWTransaction] {
            engine.store.snapshot().filter { $0.request.url.host == host }
        }

        private func segment(_ host: String, path: String = "/seg0.ts", range: Range<Int>? = 0..<1000) -> CWMediaRequestSample {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            return CWMediaRequestSample(
                kind: .segment, url: URL(string: "https://\(host)\(path)")!, mediaType: "vide",
                serverAddress: "203.0.113.9", requestStart: start, responseEnd: start.addingTimeInterval(0.25),
                byteRange: range, segmentDuration: 6
            )
        }

        @Test("a request sample becomes a read-only media row")
        func requestRow() throws {
            CWMediaRecorder.record(segment("seg.test"), itemID: itemID, record: record)

            let row = try #require(rows(host: "seg.test").first)
            #expect(row.source == .media)
            #expect(row.state == .completed)
            #expect(!row.isMockable)
            #expect(row.request.method == "GET")
            #expect(row.duration == 0.25)
            #expect(row.media?.kind == .segment)
            #expect(row.media?.itemID == itemID)
            #expect(row.media?.mediaType == "vide")
            #expect(row.media?.byteRange == 0..<1000)
            #expect(row.media?.segmentDuration == 6)
            #expect(row.media?.serverAddress == "203.0.113.9")
            #expect(row.statusText == "OK")
            #expect(CWStatusClass(row) == .success)
            #expect(CWTransactionFilter(source: .media).apply(to: [row]).count == 1)
        }

        @Test("a request CWURLProtocol already captured is not repeated as a media row")
        func skipsURLProtocolTwin() {
            let sample = segment("twin.test")
            func captured(_ path: String, after seconds: TimeInterval) -> CWTransaction {
                let recorder = CWRecorder(configuration: .default)
                let begun = recorder.begin(URLRequest(url: URL(string: "https://twin.test\(path)")!), body: nil,
                                           at: sample.requestStart.addingTimeInterval(seconds))!
                return recorder.complete(begun, response: nil, body: nil, error: nil)
            }
            engine.store.upsert(captured("/seg0.ts", after: 1))
            engine.store.upsert(captured("/seg1.ts", after: 60))

            CWMediaRecorder.record(sample, itemID: itemID, record: record)
            CWMediaRecorder.record(segment("twin.test", path: "/seg1.ts"), itemID: itemID, record: record)

            #expect(rows(host: "twin.test").filter { $0.source == .media }.map(\.request.url.path) == ["/seg1.ts"])
        }

        @Test("regression: URLs with a base (as AVFoundation reports them) match by absolute string")
        func twinWithBaseURL() {
            var sample = segment("base.test", path: "/seg0.ts")
            sample.url = URL(string: "seg0.ts", relativeTo: URL(string: "https://base.test/")!)!
            let recorder = CWRecorder(configuration: .default)
            let begun = recorder.begin(URLRequest(url: URL(string: "https://base.test/seg0.ts")!), body: nil, at: sample.requestStart)!
            engine.store.upsert(recorder.complete(begun, response: nil, body: nil, error: nil))

            CWMediaRecorder.record(sample, itemID: itemID, record: record)

            #expect(rows(host: "base.test").filter { $0.source == .media }.isEmpty)
        }

        @Test("a failed request keeps its error")
        func failedRequest() throws {
            var sample = segment("fail.test")
            sample.error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSLocalizedDescriptionKey: "timed out"])

            CWMediaRecorder.record(sample, itemID: itemID, record: record)

            let row = try #require(rows(host: "fail.test").first)
            #expect(row.state == .failed)
            #expect(row.error?.code == NSURLErrorTimedOut)
            #expect(row.statusText == "ERR")
        }

        @Test("requests per item are capped; the rest are counted, not stored")
        func perItemCap() {
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: [], maxMediaRequestsPerItem: 2))
            let capped = CWMediaItemRecord()

            for index in 0..<5 {
                CWMediaRecorder.record(segment("cap.test", path: "/seg\(index).ts"), itemID: itemID, record: capped)
            }

            #expect(rows(host: "cap.test").count == 2)
            #expect(capped.state.withLock { $0.skippedCount } == 3)
        }

        @Test("one playback-log row per URI is updated in place as the log grows")
        func playbackLog() throws {
            func sample(bytes: Int64, stalls: Int) -> CWMediaLogSample {
                CWMediaLogSample(
                    uri: URL(string: "https://log.test/master.m3u8")!, serverAddress: "198.51.100.1",
                    startDate: Date(timeIntervalSince1970: 1_700_000_000), bytesTransferred: bytes,
                    playback: CWMediaInfo.Playback(
                        transferDuration: 2, observedBitrate: 1_200_000, indicatedBitrate: 800_000,
                        stallCount: stalls, requestCount: 3, durationWatched: 10
                    )
                )
            }

            CWMediaRecorder.record(sample(bytes: 1000, stalls: 0), itemID: itemID, record: record)
            CWMediaRecorder.record(sample(bytes: 5000, stalls: 1), itemID: itemID, record: record)

            let all = rows(host: "log.test")
            let row = try #require(all.first)
            #expect(all.count == 1)
            #expect(row.media?.kind == .playbackLog)
            #expect(row.media?.bytesReceived == 5000)
            #expect(row.media?.playback?.stallCount == 1)
            #expect(row.duration == 2)
        }

        @Test("an error-log event becomes a failed row with its status and comment")
        func playbackError() throws {
            let sample = CWMediaErrorSample(
                uri: URL(string: "https://err.test/seg.ts")!, serverAddress: nil,
                date: Date(timeIntervalSince1970: 1_700_000_000), statusCode: 404,
                domain: "CoreMediaErrorDomain", comment: "HTTP 404"
            )

            CWMediaRecorder.record(sample, itemID: itemID)

            let row = try #require(rows(host: "err.test").first)
            #expect(row.state == .failed)
            #expect(row.error?.code == 404)
            #expect(row.error?.domain == "CoreMediaErrorDomain")
            #expect(row.error?.message == "HTTP 404")
            #expect(row.media?.kind == .playbackError)
        }

        @Test("nothing is recorded with captureMedia off, for an ignored host, or while stopped")
        func optOut() {
            engine.start(configuration: CWConfiguration(
                interceptCustomSessions: false, ignoredHosts: ["ignored.test"], triggers: [], captureMedia: false
            ))
            CWMediaRecorder.record(segment("off.test"), itemID: itemID, record: record)
            engine.start(configuration: CWConfiguration(
                interceptCustomSessions: false, ignoredHosts: ["ignored.test"], triggers: []
            ))
            CWMediaRecorder.record(segment("ignored.test"), itemID: itemID, record: record)
            let stopped = CWCaptureEngine()
            CWMediaRecorder.record(segment("stopped.test"), itemID: itemID, record: record, engine: stopped)

            #expect(rows(host: "off.test").isEmpty)
            #expect(rows(host: "ignored.test").isEmpty)
            #expect(stopped.store.count == 0)
        }
    }
}
#endif
