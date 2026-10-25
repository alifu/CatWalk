#if CATWALK_ENABLED
//
//  CWPreviewFixtures.swift
//  CatWalk
//

#if DEBUG
import Foundation
import SwiftUI

/// Sample data for SwiftUI previews and UI smoke tests.
enum CWPreviewFixtures {

    static let ok = make("GET", "https://dummyjson.com/products?limit=2", status: 200, json: #"{"products":[{"id":1,"title":"Phone","tags":["a","b"]}],"total":1,"ok":true,"next":null}"#)
    static let created = make("POST", "https://dummyjson.com/carts/add", status: 201, json: #"{"id":51}"#, requestBody: #"{"userId":1}"#)
    static let notFound = make("GET", "https://dummyjson.com/missing", status: 404, json: #"{"message":"Not found"}"#)
    static let failed = make("GET", "https://offline.test/ping", status: nil, json: nil)
    static let socket = makeSocket()
    static let all = [ok, created, notFound, failed, socket]

    /// A store holding `all`, for views that read from it.
    static func store() -> CWTransactionStore {
        let store = CWTransactionStore()
        all.reversed().forEach(store.upsert)
        return store
    }

    private static func make(_ method: String, _ url: String, status: Int?, json: String?, requestBody: String? = nil) -> CWTransaction {
        let recorder = CWRecorder(configuration: .default)
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let begun = recorder.begin(request, body: requestBody.map { Data($0.utf8) })!
        guard let status, let json else {
            return recorder.complete(begun, response: nil, body: nil, error: URLError(.notConnectedToInternet))
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Set-Cookie": "session=abc; Path=/; Secure; HttpOnly"]
        )
        return recorder.complete(
            begun,
            response: response,
            body: CWBody(capturing: Data(json.utf8), limit: 1 << 20),
            error: nil,
            timing: sampleTiming(from: begun.startDate)
        )
    }
}

extension CWPreviewFixtures {

    /// A closed chat socket: a JSON text echo, a binary echo, ping/pong, closed by the app with 1000.
    private static func makeSocket() -> CWTransaction {
        let recorder = CWRecorder(configuration: .default)
        let url = URL(string: "wss://ws.postman-echo.com/raw")!
        let begun = recorder.begin(URLRequest(url: url), body: nil)!.asWebSocket()
        let handshake = HTTPURLResponse(
            url: url, statusCode: 101, httpVersion: "HTTP/1.1",
            headerFields: ["Upgrade": "websocket", "Connection": "Upgrade"]
        )!
        let json = CWBody(capturing: Data(#"{"type":"hello","user":1}"#.utf8), limit: 1 << 20)
        let binary = CWBody(capturing: Data([0xDE, 0xAD, 0xBE, 0xEF]), limit: 1 << 20)
        let frames = [
            CWWebSocketFrame(direction: .sent, kind: .text, payload: json),
            CWWebSocketFrame(direction: .received, kind: .text, payload: json),
            CWWebSocketFrame(direction: .sent, kind: .binary, payload: binary),
            CWWebSocketFrame(direction: .received, kind: .binary, payload: binary),
            CWWebSocketFrame(direction: .sent, kind: .ping),
            CWWebSocketFrame(direction: .received, kind: .pong),
        ]
        let open = recorder.handshake(begun, response: handshake)
            .updatingWebSocket { frames.reduce($0) { $0.appending($1, maxFrames: 100) } }
        return recorder.complete(open, response: handshake, body: nil, error: nil)
            .updatingWebSocket { $0.closed(code: 1000, reason: nil) }
    }

    /// DNS 20 ms, connect 60 ms (TLS 40 ms), send 5 ms, wait 120 ms, receive 30 ms.
    static func sampleTiming(from start: Date) -> CWTiming {
        func interval(_ from: Double, _ to: Double) -> DateInterval {
            DateInterval(start: start.addingTimeInterval(from), end: start.addingTimeInterval(to))
        }
        return CWTiming(
            fetchStart: start,
            domainLookup: interval(0, 0.020),
            connect: interval(0.020, 0.080),
            secureConnection: interval(0.040, 0.080),
            request: interval(0.080, 0.085),
            waiting: interval(0.085, 0.205),
            response: interval(0.205, 0.235),
            fetchType: .network
        )
    }
}

#Preview("Timing") {
    CWTimingView(timing: CWPreviewFixtures.sampleTiming(from: Date())).padding()
}

#Preview("Row") {
    List(CWPreviewFixtures.all) { CWTransactionRow(transaction: $0) }.listStyle(.plain)
}

#Preview("Detail") {
    NavigationView { CWDetailView(transactionID: CWPreviewFixtures.ok.id, store: CWPreviewFixtures.store()) }
}

#Preview("WebSocket messages") {
    NavigationView { ScrollView { CWWebSocketMessagesView(log: CWPreviewFixtures.socket.webSocket!).padding() } }
}

#Preview("Mock editor") {
    CWMockEditorView(draft: CWMockDraft(from: CWPreviewFixtures.notFound))
}

#Preview("Settings") {
    NavigationView { CWSettingsView(store: CWPreviewFixtures.store()) }
}

#Preview("Dark, large text") {
    List(CWPreviewFixtures.all) { CWTransactionRow(transaction: $0) }
        .listStyle(.plain)
        .preferredColorScheme(.dark)
        .environment(\.sizeCategory, .accessibilityLarge)
}
#endif
#endif
