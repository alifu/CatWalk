#if CATWALK_ENABLED
//
//  CWTimingTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWTiming")
struct CWTimingTests {

    private struct FakeMetrics: CWTransactionMetricsDates {
        var fetchStartDate: Date?
        var domainLookupStartDate: Date?
        var domainLookupEndDate: Date?
        var connectStartDate: Date?
        var connectEndDate: Date?
        var secureConnectionStartDate: Date?
        var secureConnectionEndDate: Date?
        var requestStartDate: Date?
        var requestEndDate: Date?
        var responseStartDate: Date?
        var responseEndDate: Date?
        var resourceFetchType: URLSessionTaskMetrics.ResourceFetchType = .networkLoad
        var isReusedConnection = false
    }

    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func at(_ milliseconds: Double) -> Date {
        start.addingTimeInterval(milliseconds / 1000)
    }

    private var fullLoad: FakeMetrics {
        FakeMetrics(
            fetchStartDate: at(0),
            domainLookupStartDate: at(0), domainLookupEndDate: at(20),
            connectStartDate: at(20), connectEndDate: at(80),
            secureConnectionStartDate: at(40), secureConnectionEndDate: at(80),
            requestStartDate: at(80), requestEndDate: at(85),
            responseStartDate: at(205), responseEndDate: at(235)
        )
    }

    @Test("maps every phase, with waiting from request end to first response byte")
    func fullMapping() throws {
        let timing = CWTiming(fullLoad)

        #expect(timing.domainLookup == DateInterval(start: at(0), end: at(20)))
        #expect(timing.connect == DateInterval(start: at(20), end: at(80)))
        #expect(timing.secureConnection == DateInterval(start: at(40), end: at(80)))
        #expect(timing.request == DateInterval(start: at(80), end: at(85)))
        #expect(timing.waiting == DateInterval(start: at(85), end: at(205)))
        #expect(timing.response == DateInterval(start: at(205), end: at(235)))
        #expect(timing.fetchType == .network)
        #expect(try #require(timing.total).duration.isApproximately(0.235))
    }

    @Test("a reused plain-HTTP connection has no DNS, connect or TLS")
    func reusedConnection() {
        var metrics = fullLoad
        metrics.domainLookupStartDate = nil
        metrics.domainLookupEndDate = nil
        metrics.connectStartDate = nil
        metrics.connectEndDate = nil
        metrics.secureConnectionStartDate = nil
        metrics.secureConnectionEndDate = nil
        metrics.isReusedConnection = true

        let timing = CWTiming(metrics)

        #expect(timing.domainLookup == nil && timing.connect == nil && timing.secureConnection == nil)
        #expect(timing.isReusedConnection)
        #expect(timing.waiting != nil)
    }

    @Test("half-open or reversed intervals are dropped; cache and push fetch types map")
    func edgeCases() {
        var metrics = fullLoad
        metrics.responseEndDate = nil
        metrics.connectEndDate = at(10)
        metrics.resourceFetchType = .localCache

        let timing = CWTiming(metrics)

        #expect(timing.response == nil)
        #expect(timing.connect == nil)
        #expect(timing.fetchType == .localCache)
        metrics.resourceFetchType = .serverPush
        #expect(CWTiming(metrics).fetchType == .serverPush)
        #expect(CWTiming().total == nil)
    }

    @Test("late connection details only fill in, never erase, what is already stored")
    func connectionDetailsKeepExisting() {
        let first = CWTiming.mocked(startingAt: start, delay: 1)
        let second = CWTiming(fullLoad)
        let transaction = TransactionFixtures.make().withConnectionDetails(tls: nil, timing: first)

        #expect(transaction.withConnectionDetails(tls: nil, timing: nil).timing == first)
        #expect(transaction.withConnectionDetails(tls: nil, timing: second).timing == second)
        #expect(transaction.markedMocked().timing == first)
        #expect(transaction.markedMocked().state == .mocked)
    }

    @Test("a mocked answer waits exactly the rule's delay")
    func mocked() {
        let timing = CWTiming.mocked(startingAt: start, delay: 0.5)

        #expect(timing.fetchType == .mocked)
        #expect(timing.waiting == DateInterval(start: start, duration: 0.5))
        #expect(timing.total?.duration == 0.5)
    }

    @Test("HAR timings use the phases, -1 for phases that did not happen")
    func harTimings() throws {
        var metrics = fullLoad
        metrics.secureConnectionStartDate = nil
        metrics.secureConnectionEndDate = nil
        let transaction = TransactionFixtures.make().withConnectionDetails(tls: nil, timing: CWTiming(metrics))

        let data = try CWHARExporter.data(for: [transaction])

        let log = try #require((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["log"] as? [String: Any])
        let entry = try #require((log["entries"] as? [[String: Any]])?.first)
        let timings = try #require(entry["timings"] as? [String: Double])
        #expect(timings["dns"]?.isApproximately(20) == true)
        #expect(timings["connect"]?.isApproximately(60) == true)
        #expect(timings["ssl"] == -1)
        #expect(timings["wait"]?.isApproximately(120) == true)
        #expect(timings["receive"]?.isApproximately(30) == true)
    }
}

extension Double {
    func isApproximately(_ other: Double, tolerance: Double = 0.001) -> Bool {
        abs(self - other) <= tolerance
    }
}
#endif
