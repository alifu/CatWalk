#if CATWALK_ENABLED
//
//  CWPresentationTests.swift
//  CatWalk
//

import ObjectiveC
import Testing
import UIKit
@testable import CatWalk

extension SharedEngine {

    @Suite("Presentation", .serialized)
    @MainActor
    struct CWPresentationTests {

        @Test("the vector icon loads from the package bundle")
        func iconLoads() {
            #expect(CWIcon.image != nil)
        }

        @Test("triggers: shake by default, manual is empty")
        func triggers() {
            #expect(CWConfiguration.default.triggers == [.shake])
            #expect(CWTrigger.manual.isEmpty)
            #expect(CWConfiguration(triggers: [.shake, .floatingBubble]).triggers.contains(.floatingBubble))
        }

        @Test("the shake hook is added to UIWindow only and leaves UIResponder untouched")
        func shakeHookScope() throws {
            let selector = #selector(UIResponder.motionEnded(_:with:))
            let responderBefore = try #require(class_getInstanceMethod(UIResponder.self, selector))
            let responderImplementation = method_getImplementation(responderBefore)

            CWShakeDetector.install()
            CWShakeDetector.install()

            let responderAfter = try #require(class_getInstanceMethod(UIResponder.self, selector))
            let windowMethod = try #require(class_getInstanceMethod(UIWindow.self, selector))
            #expect(method_getImplementation(responderAfter) == responderImplementation)
            #expect(method_getImplementation(windowMethod) != responderImplementation)
        }

        @Test("a shake on a window runs without opening anything when there is no scene or capture is off")
        func shakeIsSafe() {
            CWCaptureEngine.shared.stop()
            CWPresenter.shared.configure(triggers: [.shake])
            let window = UIWindow(frame: .zero)

            window.motionEnded(.motionShake, with: nil)
            window.motionEnded(.none, with: nil)
            UIView().motionEnded(.motionShake, with: nil)
            UIViewController().motionEnded(.motionShake, with: nil)

            #expect(!CWPresenter.shared.isPresented)
        }

        @Test("the hosting controller reports leaving the screen and works as a pushed controller")
        func hostingController() {
            var disappeared = 0
            let controller = CWHostingController(onDisappear: { disappeared += 1 })
            let navigation = UINavigationController(rootViewController: UIViewController())
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = navigation
            window.makeKeyAndVisible()

            navigation.pushViewController(controller, animated: false)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            navigation.popViewController(animated: false)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            #expect(disappeared == 1)
            #expect(CatWalk.makeViewController() is CWHostingController)
        }
    }
}
#endif
