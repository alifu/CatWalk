//
//  CWHTTPRequest.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

/// A captured outgoing request.
public struct CWHTTPRequest: Sendable, Equatable {

    public let method: String

    public let url: URL

    /// Headers after redaction.
    public let headers: CWHeaders

    /// `nil` when the request had no body.
    public let body: CWBody?

    init(
        method: String,
        url: URL,
        headers: CWHeaders,
        body: CWBody?
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}
