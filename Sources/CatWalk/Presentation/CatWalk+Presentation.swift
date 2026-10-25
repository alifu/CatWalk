//
//  CatWalk+Presentation.swift
//  CatWalk
//

import SwiftUI
import UIKit

public extension View {

    /// Presents the inspector as a sheet while `isPresented` is `true`.
    /// Returns the view unchanged in builds without the inspector.
    func catWalk(isPresented: Binding<Bool>) -> some View {
        #if CATWALK_ENABLED
        sheet(isPresented: isPresented) {
            MainView(onDismiss: { isPresented.wrappedValue = false })
        }
        #else
        self
        #endif
    }
}

public extension CatWalk {

    /// Presents the inspector over the top-most view controller. Does nothing if it is already open
    /// or there is no active window.
    @MainActor
    static func present() {
        #if CATWALK_ENABLED
        CWPresenter.shared.present()
        #endif
    }

    /// Closes the inspector opened with `present()` or a trigger.
    @MainActor
    static func dismiss() {
        #if CATWALK_ENABLED
        CWPresenter.shared.dismiss()
        #endif
    }

    @MainActor
    static var isPresented: Bool {
        #if CATWALK_ENABLED
        CWPresenter.shared.isPresented
        #else
        false
        #endif
    }

    /// The inspector as a view controller to push or present yourself. Its close button pops or
    /// dismisses it. An empty controller in builds without the inspector.
    @MainActor
    static func makeViewController() -> UIViewController {
        #if CATWALK_ENABLED
        CWHostingController()
        #else
        UIViewController()
        #endif
    }
}
