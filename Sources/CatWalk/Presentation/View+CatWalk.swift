//
//  View+CatWalk.swift
//  CatWalk
//

import SwiftUI
import UIKit

public extension View {

    /// Presents the inspector as a sheet while `isPresented` is `true`.
    func catWalk(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            MainView(onDismiss: { isPresented.wrappedValue = false })
        }
    }
}

public extension CatWalk {

    /// Presents the inspector over the top-most view controller. Does nothing if it is already open
    /// or there is no active window.
    @MainActor
    static func present() {
        CWPresenter.shared.present()
    }

    /// Closes the inspector opened with `present()` or a trigger.
    @MainActor
    static func dismiss() {
        CWPresenter.shared.dismiss()
    }

    @MainActor
    static var isPresented: Bool {
        CWPresenter.shared.isPresented
    }

    /// The inspector as a view controller to push or present yourself. Its close button pops or dismisses it.
    @MainActor
    static func makeViewController() -> UIViewController {
        CWHostingController()
    }

    /// `true` when CatWalk is compiled into the app (always, until the production gate lands).
    static var isEnabled: Bool {
        true
    }
}
