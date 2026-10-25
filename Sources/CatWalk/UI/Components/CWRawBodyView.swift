#if CATWALK_ENABLED
//
//  CWRawBodyView.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// A large, already formatted body as selectable text in its own modal.
struct CWRawBodyView: View {

    let title: String
    let text: String

    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            CWSelectableText(text: text)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { presentationMode.wrappedValue.dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { UIPasteboard.general.string = text } label: { Image(systemName: "doc.on.doc") }
                            .accessibilityLabel("Copy")
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

/// `UITextView` lays out text lazily, so megabytes stay responsive where a SwiftUI `Text` does not.
private struct CWSelectableText: UIViewRepresentable {

    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.alwaysBounceVertical = true
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
    }
}
#endif
