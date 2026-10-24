//
//  UIWindow+Extension.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import SwiftUI
import UIKit

@MainActor
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // Check if the physical action was a device shake
        if motion == .motionShake {
            // Forward event processing to our library manager
            LibraryShakeCoordinator.shared.handleShakeDetected()
        }
        
        // Pass the event down the responder chain so standard app code doesn't break
        super.motionEnded(motion, with: event)
    }
}

@MainActor
public final class LibraryShakeCoordinator {
    public static let shared = LibraryShakeCoordinator()
    private var isPresented = false
    
    private init() {}
    
    fileprivate func handleShakeDetected() {
        // Prevent opening duplicate screens if already visible
        guard !isPresented else { return }
        
        // Locate the active window scene on iOS 14
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let topVC = getTopViewController(from: window.rootViewController) else {
            return
        }
        
        // Create the interface target
        let mainView = MainView { [weak self] in
            guard let self else { return }
            self.isPresented = false
        }
        
        let hostingController = UIHostingController(rootView: mainView)
        hostingController.modalPresentationStyle = .pageSheet
        
        // Present the view layout on the main thread safely
        DispatchQueue.main.async {
            self.isPresented = true
            topVC.present(hostingController, animated: true, completion: nil)
        }
    }
    
    // Core engine module to traverse root navigation stacks
    private func getTopViewController(from base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return getTopViewController(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return getTopViewController(from: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return getTopViewController(from: presented)
        }
        return base
    }
}


