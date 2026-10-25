#if CATWALK_ENABLED
//
//  CWCookieParserTests.swift
//  CatWalk
//

import Foundation
import Testing
@testable import CatWalk

@Suite("CWCookieParser")
struct CWCookieParserTests {

    private let url = URL(string: "https://api.example.com/login")!

    @Test("parses a request Cookie header")
    func requestHeader() {
        let cookies = CWCookieParser.parseCookieHeader("session=abc; theme=dark")

        #expect(cookies.map(\.name) == ["session", "theme"])
        #expect(cookies.map(\.value) == ["abc", "dark"])
    }

    @Test("skips malformed request cookie pairs")
    func malformedHeader() {
        let cookies = CWCookieParser.parseCookieHeader("novalue; =empty; ok=1;  ")

        #expect(cookies.map(\.name) == ["ok"])
    }

    @Test("keeps value containing '='")
    func valueWithEquals() {
        let cookies = CWCookieParser.parseCookieHeader("token=a=b=c")

        #expect(cookies.first?.value == "a=b=c")
    }

    @Test("header cookies win over stored cookies with the same name")
    func mergeWithStorage() throws {
        let stored = try #require(HTTPCookie(properties: [
            .name: "session", .value: "stored", .domain: "api.example.com", .path: "/"
        ]))
        let extra = try #require(HTTPCookie(properties: [
            .name: "lang", .value: "en", .domain: "api.example.com", .path: "/"
        ]))

        let cookies = CWCookieParser.requestCookies(
            cookieHeader: "session=header",
            storedCookies: [stored, extra]
        )

        #expect(cookies.map(\.name) == ["session", "lang"])
        #expect(cookies.first?.value == "header")
    }

    @Test("parses Set-Cookie attributes from response headers")
    func responseCookies() {
        let fields = ["Set-Cookie": "id=42; Path=/; Domain=api.example.com; Secure; HttpOnly"]

        let cookies = CWCookieParser.responseCookies(headerFields: fields, url: url)

        let cookie = cookies.first
        #expect(cookies.count == 1)
        #expect(cookie?.name == "id")
        #expect(cookie?.value == "42")
        #expect(cookie?.path == "/")
        #expect(cookie?.isSecure == true)
        #expect(cookie?.isHTTPOnly == true)
    }
}
#endif
