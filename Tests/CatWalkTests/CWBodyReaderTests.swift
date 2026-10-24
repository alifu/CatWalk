#if CATWALK_ENABLED
//
//  CWBodyReaderTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWBodyReader")
struct CWBodyReaderTests {

    private let url = URL(string: "https://example.com/upload")!

    @Test("returns httpBody when present")
    func httpBody() throws {
        var request = URLRequest(url: url)
        request.httpBody = Data("hello".utf8)

        let body = try CWBodyReader.body(of: request)

        #expect(body == Data("hello".utf8))
    }

    @Test("drains httpBodyStream completely")
    func bodyStream() throws {
        let payload = Data((0..<(3 * 1024 * 1024)).map { UInt8(truncatingIfNeeded: $0) })
        var request = URLRequest(url: url)
        request.httpBodyStream = InputStream(data: payload)

        let body = try CWBodyReader.body(of: request)

        #expect(body == payload)
    }

    @Test("returns nil without a body")
    func noBody() throws {
        let body = try CWBodyReader.body(of: URLRequest(url: url))

        #expect(body == nil)
    }
}
#endif
