#if CATWALK_ENABLED
//
//  CWConfigurationUpdateTests.swift
//  CatWalk
//

import Testing
@testable import CatWalk

extension SharedEngine {

    @Suite("Configuration updates", .serialized)
    struct CWConfigurationUpdateTests {

        @Test("a change keeps the other options and the runtime ignore rules")
        func keepsRules() throws {
            let engine = CWCaptureEngine.shared
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: [], captureMedia: true))
            try engine.ignore(host: "keep.test")
            defer { engine.stop() }

            engine.updateConfiguration { $0.captureMedia = false }

            #expect(engine.recorder.configuration.captureMedia == false)
            #expect(engine.recorder.configuration.captureWebSockets)
            #expect(engine.ignoredHostRules.contains("keep.test"))
            #expect(engine.isRunning)
        }

        @Test("a change while stopped does not resume capture")
        func staysStopped() {
            let engine = CWCaptureEngine.shared
            engine.start(configuration: CWConfiguration(interceptCustomSessions: false, triggers: []))
            engine.stop()

            engine.updateConfiguration { $0.captureWebSockets = false }

            #expect(!engine.isRunning)
            #expect(engine.recorder.configuration.captureWebSockets == false)
        }
    }
}
#endif
