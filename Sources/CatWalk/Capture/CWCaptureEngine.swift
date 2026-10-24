//
//  CWCaptureEngine.swift
//  CatWalk
//

import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

/// Process-wide capture state shared by `CatWalk` and `CWURLProtocol`.
final class CWCaptureEngine: Sendable {

    static let shared = CWCaptureEngine()

    let store = CWTransactionStore()

    private static let logger = Logger(subsystem: "com.catwalk", category: "engine")

    private struct Runtime {
        var isRunning = false
        var hostFilter = CWHostFilter.empty
        var recorder = CWRecorder(configuration: .default)
        var bridge: CWSessionBridge?
    }

    private let runtime = CWLocked(Runtime())

    var isRunning: Bool {
        runtime.withLock { $0.isRunning }
    }

    /// O(L) in host labels; see `CWHostFilter`.
    func isIgnored(host: String?) -> Bool {
        runtime.withLock { $0.hostFilter }.isIgnored(host)
    }

    var ignoredHostRules: [String] {
        runtime.withLock { $0.hostFilter.rules }
    }

    func ignore(host rule: String) throws {
        try updateFilter { try $0.adding(rule) }
    }

    func unignore(host rule: String) throws {
        try updateFilter { try $0.removing(rule) }
    }

    private func updateFilter(_ transform: (CWHostFilter) throws -> CWHostFilter) throws {
        try runtime.withLock { runtime in
            runtime.hostFilter = try transform(runtime.hostFilter)
        }
    }

    var recorder: CWRecorder {
        runtime.withLock { $0.recorder }
    }

    var bridge: CWSessionBridge {
        runtime.withLock { runtime in
            if let bridge = runtime.bridge {
                return bridge
            }
            let bridge = CWSessionBridge()
            runtime.bridge = bridge
            return bridge
        }
    }

    /// Starts capture, or applies a new configuration if already running.
    /// - Parameter upstreamProtocolClasses: test hook to replace the real network.
    func start(configuration: CWConfiguration, upstreamProtocolClasses: [AnyClass] = []) {
        let bridge = CWSessionBridge(protocolClasses: upstreamProtocolClasses)
        let (hostFilter, rejectedRules) = CWHostFilter.build(from: configuration.ignoredHosts)
        rejectedRules.forEach { Self.logger.warning("Ignoring invalid host rule: \($0, privacy: .public)") }

        store.configure(capacity: configuration.maxTransactions, maxTotalBodyBytes: configuration.maxTotalBodyBytes)
        CWLegacyStorageCleaner.cleanOnce()
        observeMemoryWarnings()

        let (previousBridge, wasRunning) = runtime.withLock { runtime in
            let previous = (runtime.bridge, runtime.isRunning)
            runtime = Runtime(
                isRunning: true,
                hostFilter: hostFilter,
                recorder: CWRecorder(configuration: configuration),
                bridge: bridge
            )
            return previous
        }

        previousBridge?.invalidate()

        if !wasRunning {
            URLProtocol.registerClass(CWURLProtocol.self)
        }
        if configuration.interceptCustomSessions {
            CWSessionConfigurationSwizzle.install()
        }
    }

    /// Stops capturing new requests; in-flight ones finish normally.
    /// Configuration swizzling stays installed but is inert (`canInit` returns `false`).
    func stop() {
        runtime.withLock { $0.isRunning = false }
        URLProtocol.unregisterClass(CWURLProtocol.self)
    }

    private let memoryWarningObserver = CWLocked<(any NSObjectProtocol)?>(nil)

    /// Frees captured bodies of finished transactions when the system runs low on memory.
    private func observeMemoryWarnings() {
        #if canImport(UIKit)
        memoryWarningObserver.withLock { observer in
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { [store] _ in
                store.purgeCompletedBodies()
            }
        }
        #endif
    }
}
