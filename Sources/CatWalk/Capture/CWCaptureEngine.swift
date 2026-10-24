//
//  CWCaptureEngine.swift
//  CatWalk
//

import Foundation

/// Process-wide capture state shared by `CatWalk` and `CWURLProtocol`.
final class CWCaptureEngine: Sendable {

    static let shared = CWCaptureEngine()

    let store = CWTransactionStore()

    private struct Runtime {
        var isRunning = false
        var recorder = CWRecorder(configuration: .default)
        var bridge: CWSessionBridge?
    }

    private let runtime = CWLocked(Runtime())

    var isRunning: Bool {
        runtime.withLock { $0.isRunning }
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

        let (previousBridge, wasRunning) = runtime.withLock { runtime in
            let previous = (runtime.bridge, runtime.isRunning)
            runtime = Runtime(
                isRunning: true,
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
}
