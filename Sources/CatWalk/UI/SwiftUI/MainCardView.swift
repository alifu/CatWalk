//
//  MainCardView.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 08/07/26.
//

import SwiftUI

struct MainCardView: View {
    let transaction: CWTransaction
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transaction.request.url.absoluteString).font(.body)
            if let code = transaction.response?.statusCode {
                Text("Status: \(code)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(transaction.request.method)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    MainCardView(transaction: CWRecorder(configuration: .default).begin(
        URLRequest(url: URL(string: "https://example.com")!),
        body: nil
    )!)
}
