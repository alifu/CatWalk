#if CATWALK_ENABLED
//
//  CWWebSocketLogTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("WebSocket log")
struct CWWebSocketLogTests {

    private func frame(_ text: String, _ direction: CWWebSocketFrame.Direction = .sent, limit: Int = 1024) -> CWWebSocketFrame {
        CWWebSocketFrame(direction: direction, kind: .text, payload: CWBody(capturing: Data(text.utf8), limit: limit))
    }

    @Test("keeps the newest frames up to the limit and counts the dropped ones")
    func ring() {
        let log = ["a", "bb", "ccc", "dddd", "eeeee"].reduce(CWWebSocketLog()) { $0.appending(frame($1), maxFrames: 3) }

        #expect(log.frames.map { String(decoding: $0.payload?.data ?? Data(), as: UTF8.self) } == ["ccc", "dddd", "eeeee"])
        #expect(log.droppedFrameCount == 2)
        #expect(log.storedBytes == 12)
    }

    @Test("payloads are capped like bodies; the full size is kept")
    func payloadCap() {
        let capped = frame("0123456789", limit: 4)

        #expect(capped.payload?.data.count == 4)
        #expect(capped.payload?.totalBytes == 10)
        #expect(CWWebSocketLog().appending(capped, maxFrames: 10).storedBytes == 4)
    }

    @Test("a failed send is marked on its frame without moving it")
    func failedSend() {
        let first = frame("one")
        let log = CWWebSocketLog().appending(first, maxFrames: 10).appending(frame("two", .received), maxFrames: 10)

        let failed = log.markingFailed(frameID: first.id, error: CWTransactionError(URLError(.networkConnectionLost)))

        #expect(failed.frames.first?.error?.code == URLError.networkConnectionLost.rawValue)
        #expect(failed.frames.last?.error == nil)
        #expect(log.frames.first?.error == nil)
    }

    @Test("close keeps the code and decodes the reason")
    func close() {
        let closed = CWWebSocketLog().closed(code: 1001, reason: Data("bye".utf8))

        #expect(closed.closeCode == 1001)
        #expect(closed.closeReason == "bye")
        #expect(CWWebSocketLog.closeCodeName(1001) == "Going away")
        #expect(CWWebSocketLog.closeCodeName(4000) == "Application code")
    }

    @Test("stripping keeps frame sizes, drops bytes and releases the budget")
    func stripping() {
        let log = CWWebSocketLog().appending(frame("hello"), maxFrames: 10)

        let stripped = log.strippingData()

        #expect(stripped.storedBytes == 0)
        #expect(stripped.frames.first?.payload?.totalBytes == 5)
        #expect(stripped.frames.first?.payload?.data.isEmpty == true)
    }

    @Test("WebSocket transactions count frames in the store budget and strip them on purge")
    func transactionBudget() throws {
        let begun = try #require(CWRecorder(configuration: .default).begin(URLRequest(url: URL(string: "wss://ws.test/chat")!), body: nil))
        let socket = begun.asWebSocket().updatingWebSocket { $0.appending(frame("hello"), maxFrames: 10) }

        #expect(socket.source == .webSocket)
        #expect(!socket.isMockable)
        #expect(socket.storedBodyBytes == 5)
        #expect(socket.strippingBodies().storedBodyBytes == 0)
        #expect(begun.updatingWebSocket { $0.appending(frame("x"), maxFrames: 10) }.webSocket == nil)
    }
}
#endif
