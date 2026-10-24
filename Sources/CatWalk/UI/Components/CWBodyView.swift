//
//  CWBodyView.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// A captured body as JSON tree (with a raw toggle), text, image or hex dump.
struct CWBodyView: View {

    let captured: CWBody?
    let mimeType: String?

    @State private var showsRawJSON = false

    private var preview: CWBodyPreview { CWBodyPreview.make(for: captured, mimeType: mimeType) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let captured, captured.totalBytes > 0 {
                header(captured)
            }
            content
        }
    }

    private func header(_ body: CWBody) -> some View {
        HStack {
            Text(CWFormat.bytes(body.totalBytes)).font(.caption).foregroundColor(.secondary)
            if body.isTruncated {
                Text("truncated to \(CWFormat.bytes(body.data.count))").font(.caption).foregroundColor(.orange)
            }
            Spacer()
            if case .json = preview {
                Picker("Format", selection: $showsRawJSON) {
                    Text("Tree").tag(false)
                    Text("Raw").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
            }
            if let text = copyText {
                Button { UIPasteboard.general.string = text } label: { Image(systemName: "doc.on.doc") }
                    .accessibilityLabel("Copy body")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch preview {
        case .empty:
            Text("No body").foregroundColor(.secondary)
        case let .purged(totalBytes):
            Text("Body of \(CWFormat.bytes(totalBytes)) was released after a memory warning.").foregroundColor(.secondary)
        case let .json(node, pretty):
            if showsRawJSON { codeText(pretty) } else { CWJSONTreeView(node: node) }
        case let .text(text):
            codeText(text)
        case let .image(data):
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Response image")
            } else {
                codeText("Image could not be decoded")
            }
        case let .binary(hexDump):
            codeText(hexDump)
        }
    }

    private var copyText: String? {
        switch preview {
        case let .json(_, pretty): pretty
        case let .text(text): text
        default: nil
        }
    }

    private func codeText(_ text: String) -> some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
