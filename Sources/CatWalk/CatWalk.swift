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

    /// Hosts currently excluded from capture (normalised rules, sorted).
    public static var ignoredHosts: [String] {
        CWCaptureEngine.shared.ignoredHostRules
    }

    /// Stops capturing a host. `"api.example.com"` matches that host; `"*.example.com"` matches
    /// the domain and all its subdomains. Applies to requests started after the call.
    /// - Throws: `CWConfigurationError.invalidHost` for empty, malformed or too-broad rules (`*.com`).
    public static func ignore(host: String) throws {
        try CWCaptureEngine.shared.ignore(host: host)
    }

    /// Removes a rule added with `ignore(host:)` or `CWConfiguration.ignoredHosts`.
    public static func unignore(host: String) throws {
        try CWCaptureEngine.shared.unignore(host: host)
    }
}
