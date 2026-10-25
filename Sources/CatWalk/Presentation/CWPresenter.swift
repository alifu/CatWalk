#if CATWALK_ENABLED
//
//  CWPresenter.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// Hosts `MainView` and presents it over the top-most view controller.
@MainActor
final class CWPresenter: NSObject, UIAdaptivePresentationControllerDelegate {

    static let shared = CWPresenter()

    private var presented: CWHostingController?

    /// Derived from UIKit, not from a flag the close button resets: swipe-down and programmatic
    /// dismissals are covered.
    var isPresented: Bool {
        presented?.presentingViewController != nil
    }

    private(set) var triggers: CWTrigger = []

    private lazy var bubble = CWFloatingBubble(onTap: { [weak self] in self?.present() })

    /// Called from `CatWalk.start`; safe to call repeatedly.
    func configure(triggers: CWTrigger) {
        self.triggers = triggers
        if triggers.contains(.shake) {
            CWShakeDetector.install()
        }
        if triggers.contains(.floatingBubble) {
            bubble.install()
        } else {
            bubble.remove()
        }
        bubble.setHidden(isPresented)
    }

    func handleShake() {
        guard CWCaptureEngine.shared.isRunning, triggers.contains(.shake) else { return }
        present()
    }

    func present() {
        guard !isPresented, let top = Self.topViewController() else { return }

        let controller = CWHostingController(onDisappear: { [weak self] in self?.didDismiss() })
        controller.presentationController?.delegate = self
        presented = controller
        bubble.setHidden(true)
        top.present(controller, animated: true)
    }

    func dismiss() {
        presented?.dismiss(animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didDismiss()
    }

    private func didDismiss() {
        presented = nil
        bubble.setHidden(false)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow && !($0 is CWBubbleWindow) }
            ?? scene?.windows.first { !($0 is CWBubbleWindow) }
        return top(of: window?.rootViewController)
    }

    private static func top(of controller: UIViewController?) -> UIViewController? {
        if let presented = controller?.presentedViewController {
            return top(of: presented)
        }
        if let navigation = controller as? UINavigationController {
            return top(of: navigation.visibleViewController) ?? navigation
        }
        if let tabs = controller as? UITabBarController {
            return top(of: tabs.selectedViewController) ?? tabs
        }
        return controller
    }
}

/// `MainView` for UIKit: `CatWalk.makeViewController()` and the sheet the presenter shows.
final class CWHostingController: UIHostingController<MainView> {

    private let onDisappear: () -> Void

    /// - Parameter onDisappear: called once the controller has left the screen for good.
    init(onDisappear: @escaping () -> Void = {}) {
        self.onDisappear = onDisappear
        let box = DismissBox()
        super.init(rootView: MainView(onDismiss: { MainActor.assumeIsolated { box.dismiss() } }))
        box.controller = self
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true || parent == nil {
            onDisappear()
        }
    }

    /// Lets the close button reach the controller that is created after the view.
    @MainActor
    private final class DismissBox {
        weak var controller: UIViewController?

        func dismiss() {
            guard let controller else { return }
            if let navigation = controller.navigationController, navigation.viewControllers.first !== controller {
                navigation.popViewController(animated: true)
            } else {
                controller.dismiss(animated: true)
            }
        }
    }
}
#endif
