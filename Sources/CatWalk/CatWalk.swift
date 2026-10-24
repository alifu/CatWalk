import Foundation

/// CatWalk network inspector entry point.
public enum CatWalk {

    /// Starts capturing HTTP(S) traffic.
    ///
    /// Call as early as possible (`App.init`, `application(_:didFinishLaunchingWithOptions:)`):
    /// sessions created before this call are not intercepted. Calling again applies a new configuration.
    public static func start(configuration: CWConfiguration = .default) {
        CWCaptureEngine.shared.start(configuration: configuration)
    }

    /// Stops capturing new requests. Captured transactions stay in memory until the app exits.
    public static func stop() {
        CWCaptureEngine.shared.stop()
    }

    public static var isRunning: Bool {
        CWCaptureEngine.shared.isRunning
    }
}
