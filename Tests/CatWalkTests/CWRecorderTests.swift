//
//  CWRecorderTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWRecorder")
struct CWRecorderTests {

    private let url = URL(string: "https://api.example.com/items?page=1")!
    private let start = Date(timeIntervalSince1970: 1_000)

    private func makeRecorder(maxBodyBytes: Int = 1024) -> CWRecorder {
        CWRecorder(configuration: CWConfiguration(
            maxBodyBytes: maxBodyBytes,
            redactedHeaders: ["Authorization", "Set-Cookie"]
        ))
    }

    private func makeRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpShouldHandleCookies = false
        return request
    }

    @Test("begin builds an in-flight transaction with redacted headers")
    func begin() throws {
        let transaction = try #require(makeRecorder().begin(
            makeRequest(),
            body: Data("{}".utf8),
            at: start
        ))

        #expect(transaction.state == .inFlight)
        #expect(transaction.request.method == "POST")
        #expect(transaction.request.url == url)
        #expect(transaction.request.headers["authorization"] == CWRedaction.placeholder)
        #expect(transaction.request.headers["content-type"] == "application/json")
        #expect(transaction.request.body?.data == Data("{}".utf8))
        #expect(transaction.response == nil)
        #expect(transaction.duration == nil)
    }

    @Test("begin truncates the captured request body")
    func beginTruncates() throws {
        let transaction = try #require(makeRecorder(maxBodyBytes: 2).begin(
            makeRequest(),
            body: Data("abcdef".utf8),
            at: start
        ))

        #expect(transaction.request.body?.data == Data("ab".utf8))
        #expect(transaction.request.body?.isTruncated == true)
    }

    @Test("complete records response, cookies and duration without mutating the original")
    func complete() throws {
        let recorder = makeRecorder()
        let inFlight = try #require(recorder.begin(makeRequest(), body: nil, at: start))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 201,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Set-Cookie": "id=1; Path=/"]
        ))
        let body = CWBody(capturing: Data("ok".utf8), limit: 1024)

        let done = recorder.complete(
            inFlight,
            response: response,
            body: body,
            error: nil,
            at: start.addingTimeInterval(0.5)
        )

        #expect(done.state == .completed)
        #expect(done.response?.statusCode == 201)
        #expect(done.response?.body == body)
        #expect(done.response?.headers["set-cookie"] == CWRedaction.placeholder)
        #expect(done.responseCookies.first?.value == CWRedaction.placeholder)
        #expect(done.duration == 0.5)
        #expect(inFlight.state == .inFlight)
    }

    @Test("complete with an error marks the transaction failed")
    func failure() throws {
        let recorder = makeRecorder()
        let inFlight = try #require(recorder.begin(makeRequest(), body: nil, at: start))

        let failed = recorder.complete(
            inFlight,
            response: nil,
            body: nil,
            error: URLError(.notConnectedToInternet),
            at: start.addingTimeInterval(1)
        )

        #expect(failed.state == .failed)
        #expect(failed.error?.code == URLError.notConnectedToInternet.rawValue)
        #expect(failed.error?.domain == NSURLErrorDomain)
    }

    @Test("search key contains method, url and status in lowercase")
    func searchKey() throws {
        let recorder = makeRecorder()
        let inFlight = try #require(recorder.begin(makeRequest(), body: nil, at: start))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil))

        let done = recorder.complete(inFlight, response: response, body: nil, error: nil, at: start)

        #expect(done.searchKey.contains("post"))
        #expect(done.searchKey.contains("api.example.com/items"))
        #expect(done.searchKey.contains("404"))
    }
}
