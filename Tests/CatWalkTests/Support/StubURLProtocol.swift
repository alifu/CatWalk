//
//  StubURLProtocol.swift
//  CatWalk
//

import Foundation
@testable import CatWalk

/// Upstream stand-in for the network, keyed by URL path.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    enum Reply: Sendable {
        case response(status: Int, headers: [String: String], body: Data)
        case redirect(to: URL)
        case failure(URLError.Code)
    }

    private static let replies = CWLocked<[String: Reply]>([:])
    private static let receivedBodies = CWLocked<[String: Data]>([:])

    static func stub(_ path: String, _ reply: Reply) {
        replies.withLock { $0[path] = reply }
    }

    static func receivedBody(for path: String) -> Data? {
        receivedBodies.withLock { $0[path] }
    }

    static func reset() {
        replies.withLock { $0.removeAll() }
        receivedBodies.withLock { $0.removeAll() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }

        let body = request.httpBody ?? request.httpBodyStream.flatMap { try? CWBodyReader.read($0) }
        Self.receivedBodies.withLock { $0[url.path] = body }

        let reply = Self.replies.withLock { $0[url.path] }
            ?? .response(status: 404, headers: [:], body: Data())

        switch reply {
        case let .response(status, headers, body):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)

        case let .redirect(target):
            let response = HTTPURLResponse(
                url: url,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": target.absoluteString]
            )!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)

        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}
