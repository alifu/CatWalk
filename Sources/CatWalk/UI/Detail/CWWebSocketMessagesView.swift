#if CATWALK_ENABLED && !CATWALK_EXCLUDE_WEBSOCKET
//
//  CWWebSocketMessagesView.swift
//  CatWalk
//

import SwiftUI
import UIKit

/// Counts and close status of a WebSocket, for the Overview tab.
struct CWWebSocketSummary: View {

    let log: CWWebSocketLog

    var body: some View {
        CWKeyValueRow(name: "Messages", value: "\(log.sentCount) sent · \(log.receivedCount) received")
        if log.droppedFrameCount > 0 {
            CWKeyValueRow(name: "Dropped", value: "\(log.droppedFrameCount) oldest messages")
        }
        if let code = log.closeCode {
            CWKeyValueRow(name: "Close code", value: "\(code) \(CWWebSocketLog.closeCodeName(code))")
        }
        if let reason = log.closeReason {
            CWKeyValueRow(name: "Close reason", value: reason)
        }
    }
}

/// Chat-style message list: sent on the right, received on the left.
struct CWWebSocketMessagesView: View {

    let log: CWWebSocketLog
    @State private var query = ""

    private var shown: [CWWebSocketFrame] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return log.frames }
        return log.frames.filter { $0.previewText.lowercased().contains(needle) }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            TextField("Filter messages", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            if log.droppedFrameCount > 0 {
                Text("\(log.droppedFrameCount) older messages were dropped.").font(.caption).foregroundColor(.secondary)
            }
            if shown.isEmpty {
                Text(log.frames.isEmpty ? "No messages yet" : "No messages match").foregroundColor(.secondary)
            }
            ForEach(shown) { CWWebSocketFrameRow(frame: $0) }
        }
    }
}

private struct CWWebSocketFrameRow: View {

    let frame: CWWebSocketFrame

    private var isSent: Bool { frame.direction == .sent }

    var body: some View {
        HStack {
            if isSent { Spacer(minLength: 40) }
            NavigationLink(destination: CWWebSocketFrameDetail(frame: frame)) { bubble }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { UIPasteboard.general.string = frame.previewText } label: {
                        Label("Copy message", systemImage: "doc.on.doc")
                    }
                }
            if !isSent { Spacer(minLength: 40) }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isSent ? "arrow.up" : "arrow.down")
                Text(frame.kind.title)
                if let payload = frame.payload { Text(CWFormat.bytes(payload.totalBytes)) }
                Text(frame.date.formatted(date: .omitted, time: .standard))
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            Text(frame.previewText)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(4)
            if let error = frame.error {
                Label(error.message, systemImage: "exclamationmark.triangle").font(.caption2).foregroundColor(.red)
            }
        }
        .padding(8)
        .background(isSent ? Color.accentColor.opacity(0.15) : Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isSent ? "Sent" : "Received") \(frame.kind.title): \(frame.previewText)")
    }
}

private struct CWWebSocketFrameDetail: View {

    let frame: CWWebSocketFrame

    var body: some View {
        ScrollView {
            CWBodyView(captured: frame.payload, mimeType: frame.kind == .text ? "text/plain" : "application/octet-stream")
                .padding()
        }
        .navigationTitle("\(frame.direction == .sent ? "Sent" : "Received") \(frame.kind.title.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension CWWebSocketFrame.Kind {

    var title: String {
        switch self {
        case .text: "Text"
        case .binary: "Binary"
        case .ping: "Ping"
        case .pong: "Pong"
        }
    }
}

extension CWWebSocketFrame {

    static let previewLimit = 1024

    /// Text frames as text (first `previewLimit` bytes), others described.
    var previewText: String {
        switch kind {
        case .text: String(decoding: (payload?.data ?? Data()).prefix(Self.previewLimit), as: UTF8.self)
        case .binary: "\(CWFormat.bytes(payload?.totalBytes ?? 0)) of binary data"
        case .ping, .pong: kind.title
        }
    }
}
#endif
