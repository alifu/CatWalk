//
//  DemoSwiftUIApp.swift
//  DemoSwiftUI
//
//  Created by Annur Alif Ramadhoni  on 25/06/26.
//

import SwiftUI
import CatWalk

@main
struct DemoSwiftUIApp: App {

    /// Created before `CatWalk.start` on purpose: CatWalk's load-time bootstrap still captures it.
    private let session = URLSession(configuration: .default)

    init() {
        CatWalk.start(configuration: CWConfiguration(triggers: [.shake, .floatingBubble]))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
