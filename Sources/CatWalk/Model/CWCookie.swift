//
//  CWCookie.swift
//  CatWalk
//

import Foundation

/// A cookie sent with a request or set by a response.
public struct CWCookie: Sendable, Hashable {

    public let name: String

    public let value: String

    /// `nil` for cookies parsed from a request `Cookie` header.
    public let domain: String?

    /// `nil` for cookies parsed from a request `Cookie` header.
    public let path: String?

    /// `nil` for session cookies.
    public let expiresDate: Date?

    public let isSecure: Bool

    public let isHTTPOnly: Bool

    /// `Lax`, `Strict` or `nil` when unspecified.
    public let sameSite: String?

    init(
        name: String,
        value: String,
        domain: String? = nil,
        path: String? = nil,
        expiresDate: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false,
        sameSite: String? = nil
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresDate = expiresDate
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
    }

    init(_ cookie: HTTPCookie) {
        self.init(
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path,
            expiresDate: cookie.expiresDate,
            isSecure: cookie.isSecure,
            isHTTPOnly: cookie.isHTTPOnly,
            sameSite: cookie.sameSitePolicy?.rawValue
        )
    }

    func redactingValue() -> CWCookie {
        CWCookie(
            name: name,
            value: CWRedaction.placeholder,
            domain: domain,
            path: path,
            expiresDate: expiresDate,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            sameSite: sameSite
        )
    }
}
