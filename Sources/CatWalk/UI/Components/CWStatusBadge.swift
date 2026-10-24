#if CATWALK_ENABLED
//
//  CWStatusBadge.swift
//  CatWalk
//

import SwiftUI

extension CWTransaction {

    var statusColor: Color {
        switch CWStatusClass(self) {
        case .success: .green
        case .redirect: .blue
        case .clientError: .orange
        case .serverError, .failed: .red
        case nil: .gray
        }
    }

    var statusText: String {
        if let code = response?.statusCode { return String(code) }
        return error != nil ? "ERR" : "…"
    }

    var statusDescription: String {
        if let code = response?.statusCode { return "Status \(code)" }
        return error != nil ? "Failed" : "In progress"
    }
}

struct CWStatusBadge: View {

    let transaction: CWTransaction

    var body: some View {
        Text(transaction.statusText)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(transaction.statusColor, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel(transaction.statusDescription)
    }
}

struct CWChip: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
