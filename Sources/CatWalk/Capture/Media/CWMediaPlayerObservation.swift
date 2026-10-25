#if CATWALK_ENABLED && !CATWALK_EXCLUDE_MEDIA
//
//  CWMediaPlayerObservation.swift
//  CatWalk
//

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import ObjectiveC

/// iOS 18+: follows each `AVPlayer`'s current item and subscribes to its AVMetrics events.
///
/// Lifetime matters. An `AVMetricEventStream` must be kept alive to deliver events, and it retains
/// the item it publishes for, so the stream can't hang off the item (a cycle: the item never goes
/// away). It hangs off the **player** instead, and is dropped when the player's item changes or the
/// player is released.
///
/// Players are found at creation (their initialisers are hooked), so players made before
/// `CatWalk.start` are not observed.
@available(iOS 18, macOS 15, tvOS 18, visionOS 2, *)
final class CWMediaPlayerObservation: NSObject, @unchecked Sendable {

    nonisolated(unsafe) private static let key = CWRuntime.makeKey()

    private let engine: CWCaptureEngine
    private let current = CWLocked<CWMediaStream?>(nil)
    private var token: NSKeyValueObservation?

    private init(player: AVPlayer, engine: CWCaptureEngine) {
        self.engine = engine
        super.init()
        token = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            self?.follow(player.currentItem)
        }
    }

    /// Starts observing `player` once; harmless when capture is off.
    static func observe(_ player: AVPlayer, engine: CWCaptureEngine = .shared) {
        guard engine.isRunning, engine.recorder.configuration.captureMedia else { return }
        let existing: CWMediaPlayerObservation? = CWRuntime.associated(player, key: key)
        guard existing == nil else { return }
        CWRuntime.associate(CWMediaPlayerObservation(player: player, engine: engine), with: player, key: key)
    }

    private func follow(_ item: AVPlayerItem?) {
        let stream = item.flatMap { CWMediaStream(item: $0, engine: engine) }
        current.withLock { $0 = stream }
    }
}

/// One item's event stream and its subscriber. Dropping this stops the events and releases the item.
@available(iOS 18, macOS 15, tvOS 18, visionOS 2, *)
final class CWMediaStream: NSObject, @unchecked Sendable {

    private let record: CWMediaItemRecord
    private let engine: CWCaptureEngine
    private let stream: NSObject

    /// `AVMetricEventStream` is refined for Swift, so it is driven by selector.
    init?(item: AVPlayerItem, engine: CWCaptureEngine) {
        guard
            let streamClass = NSClassFromString("AVMetricEventStream") as? NSObject.Type,
            let created = streamClass.perform(NSSelectorFromString("eventStream"))?.takeUnretainedValue() as? NSObject
        else {
            CWMediaObserver.warn("Media capture is off: AVMetricEventStream not found")
            return nil
        }
        self.record = CWMediaItemRecord.of(item)
        self.engine = engine
        self.stream = created
        super.init()
        Self.conformToSubscriber()
        _ = stream.perform(NSSelectorFromString("addPublisher:"), with: item)
        _ = stream.perform(NSSelectorFromString("setSubscriber:queue:"), with: self, with: Self.queue)
        stream.perform(NSSelectorFromString("subscribeToMetricEvents:"), with: Self.eventClasses)
    }

    private static let queue = DispatchQueue(label: "com.catwalk.media", qos: .utility)

    private static let eventClasses: [AnyClass] = [
        AVMetricHLSPlaylistRequestEvent.self,
        AVMetricHLSMediaSegmentRequestEvent.self,
        AVMetricContentKeyRequestEvent.self,
    ]

    /// `AVMetricEventStreamSubscriber` is refined for Swift too, so conformance is declared at runtime.
    private static let conformance: Void = {
        if let proto = objc_getProtocol("AVMetricEventStreamSubscriber") {
            class_addProtocol(CWMediaStream.self, proto)
        }
    }()

    private static func conformToSubscriber() {
        _ = conformance
    }

    @objc(publisher:didReceiveEvent:)
    func publisher(_ publisher: AnyObject, didReceiveEvent event: AnyObject) {
        let sample: CWMediaRequestSample? = switch event {
        case let playlist as AVMetricHLSPlaylistRequestEvent: CWMediaRequestSample(playlist)
        case let segment as AVMetricHLSMediaSegmentRequestEvent: CWMediaRequestSample(segment)
        case let key as AVMetricContentKeyRequestEvent: CWMediaRequestSample(key)
        default: nil
        }
        guard let sample else { return }
        CWMediaRecorder.record(sample, itemID: record.itemID, record: record, engine: engine)
    }
}

@available(iOS 18, macOS 15, tvOS 18, visionOS 2, *)
extension CWMediaRequestSample {

    init?(_ event: AVMetricHLSPlaylistRequestEvent) {
        guard let resource = event.mediaResourceRequestEvent else { return nil }
        self.init(resource, kind: .playlist, url: event.url, mediaType: event.mediaType.rawValue)
    }

    init?(_ event: AVMetricHLSMediaSegmentRequestEvent) {
        guard let resource = event.mediaResourceRequestEvent else { return nil }
        self.init(resource, kind: .segment, url: event.url, mediaType: event.mediaType.rawValue)
        segmentDuration = event.segmentDuration
    }

    init?(_ event: AVMetricContentKeyRequestEvent) {
        guard let resource = event.mediaResourceRequestEvent else { return nil }
        self.init(resource, kind: .contentKey, url: resource.url, mediaType: event.mediaType.rawValue)
    }

    private init?(_ resource: AVMetricMediaResourceRequestEvent, kind: CWMediaInfo.Kind, url: URL?, mediaType: String) {
        guard let url = url ?? resource.url else { return nil }
        let range = resource.byteRange
        let metrics = resource.networkTransactionMetrics
        // The request/response dates can be unset (the 2001 reference date); fall back to the
        // metrics' interval, then to when the event was published (right after the request ended).
        let end = Self.date(resource.responseEndTime) ?? metrics?.taskInterval.end ?? resource.date
        let start = Self.date(resource.requestStartTime) ?? metrics?.taskInterval.start ?? end
        self.init(
            kind: kind,
            url: url,
            mediaType: mediaType,
            serverAddress: resource.serverAddress,
            requestStart: start,
            responseEnd: max(start, end),
            byteRange: range.location == NSNotFound || range.length == 0 ? nil : range.location..<(range.location + range.length),
            wasReadFromCache: resource.wasReadFromCache,
            error: resource.errorEvent?.error as NSError?,
            metrics: metrics
        )
    }

    /// `nil` for the unset date AVFoundation reports as the reference date.
    private static func date(_ date: Date) -> Date? {
        date.timeIntervalSinceReferenceDate > 0 ? date : nil
    }
}

// MARK: - Finding players

@available(iOS 18, macOS 15, tvOS 18, visionOS 2, *)
extension CWMediaPlayerObservation {

    /// Hooks the initialisers an `AVPlayer` can be created through. Init consumes `self` and returns
    /// +1, so raw pointers keep ARC out; `observe` is idempotent, so reaching it twice is harmless.
    static func install() {
        hookInit(AVPlayer.self, "init")
        hookInit(AVPlayer.self, "initWithURL:", takesArgument: true)
        hookInit(AVPlayer.self, "initWithPlayerItem:", takesArgument: true)
        hookInit(AVQueuePlayer.self, "initWithItems:", takesArgument: true)
    }

    private static func hookInit(_ type: AnyClass, _ name: String, takesArgument: Bool = false) {
        let selector = NSSelectorFromString(name)
        let installed = CWRuntime.hook(type, selector) { original in
            guard let original else { return { () -> Void in } as @convention(block) () -> Void }
            if takesArgument {
                typealias Original = @convention(c) (UnsafeRawPointer, Selector, UnsafeRawPointer?) -> UnsafeRawPointer?
                let initialize = unsafeBitCast(original, to: Original.self)
                let block: @convention(block) (UnsafeRawPointer, UnsafeRawPointer?) -> UnsafeRawPointer? = { player, argument in
                    let created = initialize(player, selector, argument)
                    created.map(observeCreated)
                    return created
                }
                return block
            }
            typealias Original = @convention(c) (UnsafeRawPointer, Selector) -> UnsafeRawPointer?
            let initialize = unsafeBitCast(original, to: Original.self)
            let block: @convention(block) (UnsafeRawPointer) -> UnsafeRawPointer? = { player in
                let created = initialize(player, selector)
                created.map(observeCreated)
                return created
            }
            return block
        }
        if !installed {
            CWMediaObserver.warn("Media capture skips -[\(NSStringFromClass(type)) \(name)]: not found")
        }
    }

    private static func observeCreated(_ pointer: UnsafeRawPointer) {
        observe(Unmanaged<AVPlayer>.fromOpaque(pointer).takeUnretainedValue())
    }
}
#endif
#endif
