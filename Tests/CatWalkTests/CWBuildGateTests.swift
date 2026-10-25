//
//  CWBuildGateTests.swift
//  CatWalk
//

import Foundation
import SwiftUI
import Testing
import UIKit
import CatWalk

/// Compiled in every configuration: the public API must behave in both builds.
extension SharedEngine {

    @Suite("Build gate", .serialized)
    @MainActor
    struct CWBuildGateTests {

        @Test("isEnabled reports whether the inspector is compiled in")
        func isEnabled() {
            #if CATWALK_ENABLED
            #expect(CatWalk.isEnabled)
            #else
            #expect(!CatWalk.isEnabled)
            #endif
        }

        @Test("the public API can always be called without #if")
        func apiIsCallable() throws {
            CatWalk.start(configuration: CWConfiguration(triggers: []))
            try CatWalk.mock(CWMockRule.get("/x").respond())
            try CatWalk.ignore(host: "ads.example.com")
            _ = CatWalk.makeViewController()
            _ = Text("host").catWalk(isPresented: .constant(false))
            CatWalk.present()
            CatWalk.dismiss()
            CatWalk.setEnabled(false)

            #expect(!CatWalk.isRunning)
            #expect(!CatWalk.isPresented)
            CatWalk.removeAllMocks()
            try CatWalk.unignore(host: "ads.example.com")
            #if !CATWALK_ENABLED
            #expect(CatWalk.mocks.isEmpty)
            #expect(CatWalk.ignoredHosts.isEmpty)
            #endif
            CatWalk.stop()
        }

        #if CATWALK_ENABLED
        @Test("a disabled configuration does not start capture, and the kill switch stops and resumes it")
        func runtimeSwitch() {
            CatWalk.start(configuration: CWConfiguration(triggers: [], isEnabled: false))
            #expect(!CatWalk.isRunning)

            CatWalk.start(configuration: CWConfiguration(triggers: []))
            #expect(CatWalk.isRunning)

            CatWalk.setEnabled(false)
            #expect(!CatWalk.isRunning)

            CatWalk.setEnabled(true)
            #expect(CatWalk.isRunning)

            CatWalk.stop()
        }
        #endif
    }
}
