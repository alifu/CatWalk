#if CATWALK_ENABLED
//
//  CWInspectorUISmokeTests.swift
//  CatWalk
//

import SwiftUI
import Testing
import UIKit
@testable import CatWalk

/// Hosts each screen in a window and lays it out, to catch crashes the compiler cannot.
extension SharedEngine {

    @Suite("Inspector UI smoke", .serialized)
    @MainActor
    struct CWInspectorUISmokeTests {

        private func layOut<V: View>(_ view: V) {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let controller = UIHostingController(rootView: view)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            #expect(controller.view.bounds.width == 390)
        }

        @Test("main list renders captured transactions")
        func main() {
            CWCaptureEngine.shared.store.removeAll()
            CWPreviewFixtures.all.forEach(CWCaptureEngine.shared.store.upsert)

            layOut(MainView(onDismiss: {}))
            CWCaptureEngine.shared.store.removeAll()
        }

        @Test("detail view survives its transaction being updated from a background thread")
        func detailLiveUpdateOffMain() {
            let store = CWPreviewFixtures.store()
            let id = CWPreviewFixtures.ok.id
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = UIHostingController(rootView: NavigationView { CWDetailView(transactionID: id, store: store) })
            window.makeKeyAndVisible()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))

            // A replay finishes on a URLSession queue and upserts from there.
            let transaction = CWPreviewFixtures.ok
            DispatchQueue.global().async { store.upsert(transaction) }
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        }

        @Test("detail, every tab's data source, editor, mocks and settings render")
        func screens() {
            let store = CWPreviewFixtures.store()

            layOut(NavigationView { CWDetailView(transactionID: CWPreviewFixtures.ok.id, store: store) })
            layOut(NavigationView { CWDetailView(transactionID: CWPreviewFixtures.failed.id, store: store) })
            layOut(NavigationView { CWDetailView(transactionID: CWPreviewFixtures.socket.id, store: store) })
            layOut(NavigationView { CWDetailView(transactionID: CWPreviewFixtures.segment.id, store: store) })
            layOut(NavigationView { CWDetailView(transactionID: CWPreviewFixtures.playbackLog.id, store: store) })
            layOut(NavigationView { ScrollView { CWWebSocketMessagesView(log: CWPreviewFixtures.socket.webSocket!) } })
            layOut(NavigationView { CWDetailView(transactionID: UUID(), store: store) })
            layOut(CWMockEditorView(draft: CWMockDraft(from: CWPreviewFixtures.notFound)))
            layOut(NavigationView { CWMockListView() })
            layOut(NavigationView { CWSettingsView(store: store) })
        }
    }
}
#endif
