#if CATWALK_ENABLED
//
//  CWBodyView.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// A captured body as JSON tree (searchable, with a raw toggle), text, image or hex dump.
struct CWBodyView: View {

    let captured: CWBody?
    let mimeType: String?

    /// Raw text beyond this is never laid out inline; a button opens it in a modal.
    static let inlineRawLimit = 1000

    @State private var preview: CWBodyPreview?
    @State private var showsRawJSON = false
    @State private var showsFormatted = false
    @State private var query = ""

    /// Changes only when the captured bytes change, so the preview is built once per body.
    private var identity: [Int] { [captured?.totalBytes ?? 0, captured?.storedBytes ?? 0] }

    /// O(1): compares the stored byte count; the text itself is never measured.
    private var isLargeRaw: Bool { (captured?.storedBytes ?? 0) > Self.inlineRawLimit }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let captured, captured.totalBytes > 0 {
                header(captured)
            }
            if let preview {
                content(preview)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task(id: identity) {
            let body = captured
            let mime = mimeType
            preview = await Task.detached(priority: .userInitiated) { CWBodyPreview.make(for: body, mimeType: mime) }.value
        }
    }

    private func header(_ body: CWBody) -> some View {
        HStack {
            Text(CWFormat.bytes(body.totalBytes)).font(.caption).foregroundColor(.secondary)
            if body.isTruncated {
                Text("truncated to \(CWFormat.bytes(body.storedBytes))").font(.caption).foregroundColor(.orange)
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
    private func content(_ preview: CWBodyPreview) -> some View {
        switch preview {
        case .empty:
            Text("No body").foregroundColor(.secondary)
        case let .purged(totalBytes):
            Text("Body of \(CWFormat.bytes(totalBytes)) was released after a memory warning.").foregroundColor(.secondary)
        case let .json(node, pretty):
            if showsRawJSON {
                rawText(pretty)
            } else {
                TextField("Search keys and values", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                CWJSONTreeView(node: node, query: query)
            }
        case let .text(text):
            rawText(text)
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

    /// Inline for short bodies; long ones open formatted in a modal.
    @ViewBuilder
    private func rawText(_ text: String) -> some View {
        if isLargeRaw {
            Button { showsFormatted = true } label: {
                Label("Show formatted body", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showsFormatted) { CWRawBodyView(title: "Body", text: text) }
        } else {
            codeText(text)
        }
    }

    private func codeText(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
