#if CATWALK_ENABLED
//
//  CWTransactionRow.swift
//  CatWalk
//

import SwiftUI

struct CWTransactionRow: View {

    let transaction: CWTransaction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CWStatusBadge(transaction: transaction)
                .frame(minWidth: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(transaction.request.method).font(.caption.weight(.bold)).foregroundColor(.secondary)
                    Text(transaction.request.url.host ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Text(path).font(.footnote).foregroundColor(.secondary).lineLimit(2)
                details
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var path: String {
        let url = transaction.request.url
        let query = url.query.map { "?\($0)" } ?? ""
        return (url.path.isEmpty ? "/" : url.path) + query
    }

    private var details: some View {
        HStack(spacing: 8) {
            if let duration = transaction.duration {
                Text(CWFormat.duration(duration))
            }
            if let size = transaction.response?.body?.totalBytes {
                Text(CWFormat.bytes(size))
            }
            if let webSocket = transaction.webSocket {
                Text("\(webSocket.frames.count + webSocket.droppedFrameCount) msgs")
            }
            if transaction.tls != nil {
                Image(systemName: "lock.fill").accessibilityLabel("Secure connection")
            }
            if let chip = transaction.source.chip {
                Text(chip)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 4)
                    .overlay(Capsule().stroke(Color.secondary))
                    .accessibilityLabel(transaction.source.title)
            }
            if transaction.isMocked {
                Image(systemName: "theatermasks.fill").foregroundColor(.purple).accessibilityLabel("Mocked")
            }
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}
#endif
