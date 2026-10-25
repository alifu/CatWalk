#if CATWALK_ENABLED
//
//  CWShareSheet.swift
//  CatWalk
//

import SwiftUI
import UIKit

struct CWShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Something to hand to the share sheet; `Identifiable` so it can drive `.sheet(item:)`.
struct CWShareItem: Identifiable {
    let id = UUID()
    let items: [Any]

    static func text(_ text: String) -> CWShareItem {
        CWShareItem(items: [text])
    }

    static func har(for transactions: [CWTransaction]) -> CWShareItem? {
        guard
            let data = try? CWHARExporter.data(for: transactions),
            case let url = FileManager.default.temporaryDirectory.appendingPathComponent("catwalk.har"),
            (try? data.write(to: url, options: .atomic)) != nil
        else {
            return nil
        }
        return CWShareItem(items: [url])
    }
}
#endif
