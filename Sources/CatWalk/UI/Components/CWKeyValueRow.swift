//
//  CWKeyValueRow.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// Name above value; long-press copies the value.
struct CWKeyValueRow: View {

    let name: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.caption).foregroundColor(.secondary)
            Text(value).font(.footnote).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button { UIPasteboard.general.string = value } label: { Label("Copy value", systemImage: "doc.on.doc") }
            Button { UIPasteboard.general.string = "\(name): \(value)" } label: { Label("Copy row", systemImage: "doc.on.doc.fill") }
        }
        .accessibilityElement(children: .combine)
    }
}
