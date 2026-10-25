#if CATWALK_ENABLED
//
//  CWMediaSamples.swift
//  CatWalk
//

import Foundation

/// A finished media request as reported by AVMetrics (iOS 18+). A plain value so the mapping to
/// transactions can be tested without constructing AVFoundation events.
struct CWMediaRequestSample: Sendable {
    var kind: CWMediaInfo.Kind
    var url: URL
    var mediaType: String?
    var serverAddress: String?
    var requestStart: Date
    var responseEnd: Date
    var byteRange: Range<Int>?
    var segmentDuration: TimeInterval?
    var wasReadFromCache = false
    var error: NSError?
    var metrics: URLSessionTaskMetrics?
}

/// A playback session's access-log event (before iOS 18).
struct CWMediaLogSample: Sendable {
    var uri: URL
    var serverAddress: String?
    var startDate: Date
    var bytesTransferred: Int64
    var playback: CWMediaInfo.Playback
}

/// An error-log event (before iOS 18).
struct CWMediaErrorSample: Sendable {
    var uri: URL?
    var serverAddress: String?
    var date: Date
    var statusCode: Int
    var domain: String
    var comment: String?
}
#endif
