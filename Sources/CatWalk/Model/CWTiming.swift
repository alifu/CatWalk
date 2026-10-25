#if CATWALK_ENABLED
//
//  CWTiming.swift
//  CatWalk
//

import Foundation

/// Where the time of one exchange went, from `URLSessionTaskTransactionMetrics`.
///
/// Phases a load did not go through are `nil`: DNS and connect on a reused connection,
/// TLS on plain HTTP, everything but `waiting` for a mocked response.
public struct CWTiming: Sendable, Equatable {

    public enum FetchType: Sendable, Equatable {
        case network
        case localCache
        case serverPush
        /// Answered by a `CWMockRule`; `waiting` is the rule's delay.
        case mocked
        case unknown
    }

    public let fetchStart: Date?
    public let domainLookup: DateInterval?
    /// TCP (or QUIC) connection, including the TLS handshake.
    public let connect: DateInterval?
    public let secureConnection: DateInterval?
    /// Sending the request headers and body.
    public let request: DateInterval?
    /// Request sent until the first response byte (time to first byte).
    public let waiting: DateInterval?
    /// First to last response byte.
    public let response: DateInterval?
    public let fetchType: FetchType
    public let isReusedConnection: Bool

    /// From the first to the last recorded date, `nil` when nothing was recorded.
    public var total: DateInterval? {
        let intervals = [domainLookup, connect, secureConnection, request, waiting, response].compactMap { $0 }
        let starts = intervals.map(\.start) + [fetchStart].compactMap { $0 }
        guard let start = starts.min(), let end = intervals.map(\.end).max() else { return nil }
        return DateInterval(start: start, end: max(start, end))
    }

    init(
        fetchStart: Date? = nil,
        domainLookup: DateInterval? = nil,
        connect: DateInterval? = nil,
        secureConnection: DateInterval? = nil,
        request: DateInterval? = nil,
        waiting: DateInterval? = nil,
        response: DateInterval? = nil,
        fetchType: FetchType = .unknown,
        isReusedConnection: Bool = false
    ) {
        self.fetchStart = fetchStart
        self.domainLookup = domainLookup
        self.connect = connect
        self.secureConnection = secureConnection
        self.request = request
        self.waiting = waiting
        self.response = response
        self.fetchType = fetchType
        self.isReusedConnection = isReusedConnection
    }

    /// O(1): reads one transaction's dates.
    init(_ metrics: some CWTransactionMetricsDates) {
        self.init(
            fetchStart: metrics.fetchStartDate,
            domainLookup: Self.interval(metrics.domainLookupStartDate, metrics.domainLookupEndDate),
            connect: Self.interval(metrics.connectStartDate, metrics.connectEndDate),
            secureConnection: Self.interval(metrics.secureConnectionStartDate, metrics.secureConnectionEndDate),
            request: Self.interval(metrics.requestStartDate, metrics.requestEndDate),
            waiting: Self.interval(metrics.requestEndDate, metrics.responseStartDate),
            response: Self.interval(metrics.responseStartDate, metrics.responseEndDate),
            fetchType: Self.fetchType(metrics.resourceFetchType),
            isReusedConnection: metrics.isReusedConnection
        )
    }

    /// A mocked answer: the only phase is the rule's delay.
    static func mocked(startingAt start: Date, delay: TimeInterval) -> CWTiming {
        CWTiming(fetchStart: start, waiting: DateInterval(start: start, duration: max(0, delay)), fetchType: .mocked)
    }

    private static func interval(_ start: Date?, _ end: Date?) -> DateInterval? {
        guard let start, let end, end >= start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func fetchType(_ type: URLSessionTaskMetrics.ResourceFetchType) -> FetchType {
        switch type {
        case .networkLoad: .network
        case .localCache: .localCache
        case .serverPush: .serverPush
        default: .unknown
        }
    }
}

/// The dates CatWalk reads from `URLSessionTaskTransactionMetrics`, which tests cannot construct.
protocol CWTransactionMetricsDates {
    var fetchStartDate: Date? { get }
    var domainLookupStartDate: Date? { get }
    var domainLookupEndDate: Date? { get }
    var connectStartDate: Date? { get }
    var connectEndDate: Date? { get }
    var secureConnectionStartDate: Date? { get }
    var secureConnectionEndDate: Date? { get }
    var requestStartDate: Date? { get }
    var requestEndDate: Date? { get }
    var responseStartDate: Date? { get }
    var responseEndDate: Date? { get }
    var resourceFetchType: URLSessionTaskMetrics.ResourceFetchType { get }
    var isReusedConnection: Bool { get }
}

extension URLSessionTaskTransactionMetrics: CWTransactionMetricsDates {}
#endif
