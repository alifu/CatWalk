import Foundation

/// CatWalk network inspector entry point.
///
/// In builds without `CATWALK_ENABLED` (Release, unless the `CatWalkAlwaysOn` package trait is on)
/// every member below exists but does nothing, so host code needs no `#if`.
public enum CatWalk {

    /// Starts capturing HTTP(S) traffic.
    ///
    /// Call as early as possible (`App.init`, `application(_:didFinishLaunchingWithOptions:)`):
    /// sessions created before this call are not intercepted. Calling again applies a new configuration.
    /// Does nothing when `configuration.isEnabled` is `false` (and stops a running capture).
    public static func start(configuration: CWConfiguration = .default) {
        #if CATWALK_ENABLED
        guard configuration.isEnabled else {
            setEnabled(false)
            return
        }
        CWCaptureEngine.shared.start(configuration: configuration)
        #endif
    }

    /// Stops capturing new requests. Captured transactions stay in memory until the app exits.
    public static func stop() {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.stop()
        #endif
    }

    /// Runtime kill switch: `false` stops capture and hides the bubble; `true` resumes with the
    /// last configuration. Has no effect before `start`.
    public static func setEnabled(_ isEnabled: Bool) {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.setCapturing(isEnabled)
        let triggers = isEnabled ? CWCaptureEngine.shared.recorder.configuration.triggers : []
        Task { @MainActor in CWPresenter.shared.configure(triggers: triggers) }
        #endif
    }

    public static var isRunning: Bool {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.isRunning
        #else
        false
        #endif
    }

    /// `true` when the inspector is compiled in (Debug, or Release with the `CatWalkAlwaysOn` trait).
    public static var isEnabled: Bool {
        #if CATWALK_ENABLED
        true
        #else
        false
        #endif
    }

    /// Hosts currently excluded from capture (normalised rules, sorted).
    public static var ignoredHosts: [String] {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.ignoredHostRules
        #else
        []
        #endif
    }

    /// Stops capturing a host. `"api.example.com"` matches that host; `"*.example.com"` matches
    /// the domain and all its subdomains. Applies to requests started after the call.
    /// - Throws: `CWConfigurationError.invalidHost` for empty, malformed or too-broad rules (`*.com`).
    public static func ignore(host: String) throws {
        #if CATWALK_ENABLED
        try CWCaptureEngine.shared.ignore(host: host)
        #endif
    }

    /// Removes a rule added with `ignore(host:)` or `CWConfiguration.ignoredHosts`.
    public static func unignore(host: String) throws {
        #if CATWALK_ENABLED
        try CWCaptureEngine.shared.unignore(host: host)
        #endif
    }

    // MARK: - Mocking

    /// Answers matching requests with a canned response instead of calling the network.
    /// Adding a rule with an existing `id` replaces it. Rules live until the app exits.
    /// - Throws: `CWConfigurationError.invalidMockPattern` for a `.regex` that does not compile.
    public static func mock(_ rule: CWMockRule) throws {
        #if CATWALK_ENABLED
        try CWCaptureEngine.shared.mocks.add(rule)
        #endif
    }

    public static func removeMock(id: UUID) {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.mocks.remove(id: id)
        #endif
    }

    public static func removeAllMocks() {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.mocks.removeAll()
        #endif
    }

    /// Registered rules in insertion order. Exact-URL rules are tried before pattern rules.
    public static var mocks: [CWMockRule] {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.mocks.rules
        #else
        []
        #endif
    }

    public static func setMock(id: UUID, enabled: Bool) {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.mocks.setEnabled(enabled, for: id)
        #endif
    }

    /// Requests answered by the rule since it was added.
    public static func mockHitCount(id: UUID) -> Int {
        #if CATWALK_ENABLED
        CWCaptureEngine.shared.mocks.hitCount(for: id)
        #else
        0
        #endif
    }
}
