#if CATWALK_ENABLED
//
//  CWDetailView.swift
//  CatWalk
//

import Combine
import SwiftUI

/// One transaction, kept live while it is in flight.
struct CWDetailView: View {

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", request = "Request", response = "Response", messages = "Messages"
        case headers = "Headers", cookies = "Cookies", ssl = "SSL"
        var id: String { rawValue }

        /// WebSockets have messages instead of request/response bodies.
        static func tabs(for transaction: CWTransaction?) -> [Tab] {
            if transaction?.webSocket != nil { return [.overview, .messages, .headers, .cookies, .ssl] }
            // Media loads have no bodies or cookies; their fields are on Overview.
            if transaction?.media != nil { return [.overview, .headers, .ssl] }
            return [.overview, .request, .response, .headers, .cookies, .ssl]
        }
    }

    let transactionID: UUID
    let store: CWTransactionStore

    @State private var transaction: CWTransaction?
    @State private var tab = Tab.overview
    @State private var mockDraft: CWMockDraftItem?
    @State private var shareItem: CWShareItem?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(Tab.tabs(for: transaction)) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            if let transaction {
                ScrollView { content(for: transaction).padding([.horizontal, .bottom]) }
            } else {
                Spacer()
                Text("This request is no longer stored.").foregroundColor(.secondary)
                Spacer()
            }
        }
        .navigationTitle(transaction.map { "\($0.request.method) \($0.request.url.path)" } ?? "Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { if let transaction { actions(for: transaction) } } }
        .sheet(item: $mockDraft) { CWMockEditorView(draft: $0.draft) }
        .sheet(item: $shareItem) { CWShareSheet(items: $0.items) }
        .onAppear { transaction = store.transaction(id: transactionID) }
        .onReceive(store.changes.filter { $0 == .upserted(transactionID) }.receive(on: DispatchQueue.main)) { _ in
            transaction = store.transaction(id: transactionID) ?? transaction
        }
    }

    @ViewBuilder
    private func content(for transaction: CWTransaction) -> some View {
        switch tab {
        case .overview: CWOverviewTab(transaction: transaction)
        case .request: CWPayloadTab(captured: transaction.request.body, mimeType: transaction.request.headers["Content-Type"])
        case .response: CWPayloadTab(captured: transaction.response?.body, mimeType: transaction.response?.mimeType)
        case .messages: transaction.webSocket.map { CWWebSocketMessagesView(log: $0) }
        case .headers: CWHeadersTab(transaction: transaction)
        case .cookies: CWCookiesTab(transaction: transaction)
        case .ssl: CWSSLTab(tls: transaction.tls, isHTTPS: transaction.request.url.scheme == "https")
        }
    }

    private func actions(for transaction: CWTransaction) -> some View {
        Menu {
            Button { UIPasteboard.general.string = transaction.request.url.absoluteString } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
            Button { UIPasteboard.general.string = CWCurlExporter.command(for: transaction) } label: {
                Label("Copy as cURL", systemImage: "terminal")
            }
            Button { shareItem = CWShareItem.har(for: [transaction]) } label: {
                Label("Share HAR", systemImage: "square.and.arrow.up")
            }
            if transaction.webSocket == nil, transaction.media == nil {
                Button { replay(transaction) } label: { Label("Replay request", systemImage: "arrow.clockwise") }
            }
            if transaction.isMockable {
                Button { mockDraft = CWMockDraftItem(CWMockDraft(from: transaction)) } label: {
                    Label("Mock this response", systemImage: "theatermasks")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Actions")
    }

    /// Sent through the shared session, so the replay is captured like any other request.
    private func replay(_ transaction: CWTransaction) {
        URLSession.shared.dataTask(with: transaction.request.replayRequest).resume()
    }
}

// MARK: - Tabs

private struct CWOverviewTab: View {

    let transaction: CWTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { CWStatusBadge(transaction: transaction); if transaction.isMocked { Label("Mocked", systemImage: "theatermasks.fill").foregroundColor(.purple) } }
            CWKeyValueRow(name: "URL", value: transaction.request.url.absoluteString)
            CWKeyValueRow(name: "Method", value: transaction.request.method)
            if transaction.source != .urlSession {
                CWKeyValueRow(name: "Source", value: transaction.source.title)
            }
            CWKeyValueRow(name: "Started", value: transaction.startDate.formatted(date: .abbreviated, time: .standard))
            if let duration = transaction.duration {
                CWKeyValueRow(name: "Duration", value: CWFormat.duration(duration))
            }
            if let webSocket = transaction.webSocket {
                CWWebSocketSummary(log: webSocket)
            } else if let media = transaction.media {
                CWMediaSummary(media: media)
            } else {
                CWKeyValueRow(name: "Request body", value: size(transaction.request.body))
                CWKeyValueRow(name: "Response body", value: size(transaction.response?.body))
            }
            if let mime = transaction.response?.mimeType {
                CWKeyValueRow(name: "Content type", value: mime)
            }
            if let error = transaction.error {
                CWKeyValueRow(name: "Error", value: "\(error.message) (\(error.domain) \(error.code))")
            }
            if let timing = transaction.timing {
                Divider()
                CWTimingView(timing: timing)
            }
        }
    }

    private func size(_ body: CWBody?) -> String {
        body.map { CWFormat.bytes($0.totalBytes) } ?? "—"
    }
}

private struct CWPayloadTab: View {

    let captured: CWBody?
    let mimeType: String?

    var body: some View { CWBodyView(captured: captured, mimeType: mimeType) }
}

private struct CWHeadersTab: View {

    let transaction: CWTransaction
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Filter headers", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            section("Request", transaction.request.headers)
            if let response = transaction.response {
                section("Response", response.headers)
            }
        }
    }

    private func section(_ title: String, _ headers: CWHeaders) -> some View {
        let needle = query.lowercased()
        let shown = headers.entries.filter { needle.isEmpty || $0.name.lowercased().contains(needle) || $0.value.lowercased().contains(needle) }
        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if shown.isEmpty { Text("None").foregroundColor(.secondary) }
            ForEach(shown, id: \.self) { CWKeyValueRow(name: $0.name, value: $0.value) }
        }
    }
}

private struct CWCookiesTab: View {

    let transaction: CWTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Sent", transaction.requestCookies)
            section("Received", transaction.responseCookies)
        }
    }

    private func section(_ title: String, _ cookies: [CWCookie]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if cookies.isEmpty { Text("None").foregroundColor(.secondary) }
            ForEach(cookies, id: \.self) { cookie in
                VStack(alignment: .leading, spacing: 4) {
                    CWKeyValueRow(name: cookie.name, value: cookie.value)
                    Text(attributes(of: cookie)).font(.caption2).foregroundColor(.secondary)
                }
                Divider()
            }
        }
    }

    private func attributes(of cookie: CWCookie) -> String {
        [
            cookie.domain.map { "Domain=\($0)" },
            cookie.path.map { "Path=\($0)" },
            cookie.expiresDate.map { "Expires=\($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Session",
            cookie.isSecure ? "Secure" : nil,
            cookie.isHTTPOnly ? "HttpOnly" : nil,
            cookie.sameSite.map { "SameSite=\($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct CWSSLTab: View {

    let tls: CWTLSInfo?
    let isHTTPS: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tls {
                CWKeyValueRow(name: "Protocol", value: tls.protocolName ?? "Unknown")
                CWKeyValueRow(name: "Cipher suite", value: tls.cipherSuiteName ?? "Unknown")
                CWKeyValueRow(name: "Server", value: [tls.remoteAddress, tls.remotePort.map(String.init)].compactMap { $0 }.joined(separator: ":"))
                CWKeyValueRow(name: "Connection", value: connection(tls))
                if let decision = tls.trustDecision {
                    CWKeyValueRow(name: "App's trust decision", value: "\(decision)")
                }
                if tls.isChainFromEarlierConnection {
                    Text("No handshake on this request; the chain is from an earlier connection to the same host.")
                        .font(.caption).foregroundColor(.secondary)
                }
                ForEach(Array(tls.certificates.enumerated()), id: \.element.id) { index, certificate in
                    CWCertificateView(index: index, certificate: certificate)
                }
            } else {
                Text(isHTTPS ? "No TLS details were captured." : "Plain HTTP: no TLS.").foregroundColor(.secondary)
            }
        }
    }

    private func connection(_ tls: CWTLSInfo) -> String {
        [tls.isReusedConnection ? "Reused" : "New", tls.isProxyConnection ? "via proxy" : nil].compactMap { $0 }.joined(separator: ", ")
    }
}

private struct CWCertificateView: View {

    let index: Int
    let certificate: CWCertificate
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let subject = certificate.subject { CWKeyValueRow(name: "Subject", value: subject) }
                if let issuer = certificate.issuer { CWKeyValueRow(name: "Issuer", value: issuer) }
                if let serial = certificate.serialNumber { CWKeyValueRow(name: "Serial", value: serial) }
                if let from = certificate.notBefore { CWKeyValueRow(name: "Valid from", value: from.formatted(date: .abbreviated, time: .omitted)) }
                if let until = certificate.notAfter { CWKeyValueRow(name: "Valid until", value: until.formatted(date: .abbreviated, time: .omitted)) }
                if let key = certificate.publicKey { CWKeyValueRow(name: "Public key", value: "\(key.type) \(key.sizeInBits) bit") }
                CWKeyValueRow(name: "SHA-256 fingerprint", value: certificate.sha256Fingerprint)
                if let pin = certificate.publicKeySHA256 { CWKeyValueRow(name: "SPKI SHA-256 (pin)", value: pin) }
            }
            .padding(.top, 4)
        } label: {
            Text("\(index + 1). \(certificate.summary ?? "Certificate")").font(.subheadline.weight(.semibold))
        }
    }
}
#endif
