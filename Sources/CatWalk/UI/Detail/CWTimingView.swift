#if CATWALK_ENABLED
//
//  CWTimingView.swift
//  CatWalk
//

import SwiftUI

/// Waterfall of the load phases, each bar placed on the exchange's own time axis.
struct CWTimingView: View {

    let timing: CWTiming

    private struct Phase: Identifiable {
        let name: String
        let interval: DateInterval
        let color: Color
        var id: String { name }
    }

    private var phases: [Phase] {
        [
            ("DNS", timing.domainLookup, Color.teal),
            ("Connect", timing.connect, Color.orange),
            ("TLS", timing.secureConnection, Color.purple),
            ("Send", timing.request, Color.blue),
            ("Wait", timing.waiting, Color.gray),
            ("Receive", timing.response, Color.green),
        ]
        .compactMap { name, interval, color in interval.map { Phase(name: name, interval: $0, color: color) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Timing").font(.headline)
                Spacer()
                if let total = timing.total {
                    Text(CWFormat.duration(total.duration)).font(.caption.monospacedDigit()).foregroundColor(.secondary)
                }
            }
            if let note {
                Text(note).font(.caption).foregroundColor(.secondary)
            }
            if let total = timing.total {
                ForEach(phases) { row($0, total: total) }
            }
        }
    }

    private var note: String? {
        switch timing.fetchType {
        case .localCache: "Served from the local cache."
        case .serverPush: "Delivered by HTTP/2 server push."
        case .mocked: "Answered by a mock rule; the wait is its delay."
        case .network, .unknown: timing.isReusedConnection ? "Reused connection: no DNS, connect or TLS." : nil
        }
    }

    private func row(_ phase: Phase, total: DateInterval) -> some View {
        HStack(spacing: 8) {
            Text(phase.name).font(.caption).frame(width: 56, alignment: .leading)
            GeometryReader { proxy in
                let scale = total.duration > 0 ? proxy.size.width / total.duration : 0
                let offset = phase.interval.start.timeIntervalSince(total.start) * scale
                RoundedRectangle(cornerRadius: 2)
                    .fill(phase.color)
                    .frame(width: max(2, phase.interval.duration * scale), height: 10)
                    .offset(x: min(offset, max(0, proxy.size.width - 2)))
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)
            Text(CWFormat.duration(phase.interval.duration))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(phase.name), \(CWFormat.duration(phase.interval.duration))")
    }
}
#endif
