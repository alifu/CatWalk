//
//  MainCardView.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 08/07/26.
//

import SwiftUI

struct MainCardView: View {
    let log: APILogModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.url).font(.body)
            if let code = log.statusCode {
                Text("Status: \(code)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(log.method)
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
    MainCardView(log: APILogModel(
        id: UUID(),
        url: "https://example.com",
        method: "GET",
        requestHeaders: [:],
        requestBody: nil,
        startTime: Date()
    ))
}
