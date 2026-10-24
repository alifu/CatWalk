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
    
    init() {
        CWAPILogger.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
