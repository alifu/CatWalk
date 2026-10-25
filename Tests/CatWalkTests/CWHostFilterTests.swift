#if CATWALK_ENABLED
//
//  CWHostFilterTests.swift
//  CatWalk
//

import Testing
@testable import CatWalk

@Suite("CWHostFilter")
struct CWHostFilterTests {

    private func filter(_ rules: String...) throws -> CWHostFilter {
        try rules.reduce(CWHostFilter.empty) { try $0.adding($1) }
    }

    @Test("exact rule matches only that host, case-insensitively")
    func exact() throws {
        let filter = try filter("API.Example.com")

        #expect(filter.isIgnored("api.example.com"))
        #expect(filter.isIgnored("API.EXAMPLE.COM"))
        #expect(!filter.isIgnored("example.com"))
        #expect(!filter.isIgnored("x.api.example.com"))
    }

    @Test("wildcard matches apex and any depth of subdomain")
    func wildcard() throws {
        let filter = try filter("*.example.com")

        #expect(filter.isIgnored("example.com"))
        #expect(filter.isIgnored("a.example.com"))
        #expect(filter.isIgnored("a.b.example.com"))
    }

    @Test("wildcard does not match look-alike domains")
    func lookAlike() throws {
        let filter = try filter("*.example.com")

        #expect(!filter.isIgnored("notexample.com"))
        #expect(!filter.isIgnored("example.com.evil.io"))
        #expect(!filter.isIgnored("com"))
    }

    @Test("trailing dot and surrounding whitespace are ignored")
    func normalisation() throws {
        let filter = try filter("  api.example.com. ")

        #expect(filter.isIgnored("api.example.com"))
        #expect(filter.isIgnored("api.example.com."))
        #expect(filter.rules == ["api.example.com"])
    }

    @Test("scheme-prefixed input is reduced to its host")
    func schemePrefixed() throws {
        let filter = try filter("https://api.example.com:8443/v1")

        #expect(filter.rules == ["api.example.com"])
    }

    @Test("invalid rules are rejected", arguments: [
        "", "   ", "*.com", "*", "*.", "a b.com", "exa$mple.com", "a..com", "http://", "[::1]"
    ])
    func invalid(rule: String) {
        #expect(throws: CWConfigurationError.invalidHost(rule)) {
            try CWHostFilter.empty.adding(rule)
        }
    }

    @Test("removing a rule leaves the others; filters are immutable")
    func removing() throws {
        let original = try filter("a.com", "*.b.com")

        let reduced = try original.removing("*.b.com")

        #expect(original.isIgnored("x.b.com"))
        #expect(!reduced.isIgnored("x.b.com"))
        #expect(reduced.isIgnored("a.com"))
    }

    @Test("build skips invalid rules and reports them")
    func build() {
        let result = CWHostFilter.build(from: ["ok.com", "*.com", "also.ok"])

        #expect(result.filter.rules == ["also.ok", "ok.com"])
        #expect(result.rejected == ["*.com"])
    }

    @Test("nil, empty and unrelated hosts are not ignored")
    func noMatch() throws {
        let filter = try filter("a.com")

        #expect(!filter.isIgnored(nil))
        #expect(!filter.isIgnored(""))
        #expect(!CWHostFilter.empty.isIgnored("a.com"))
    }
}
#endif
