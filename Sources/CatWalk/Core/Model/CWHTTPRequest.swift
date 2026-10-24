//
//  CWHTTPRequest.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

public struct CWHTTPRequest: Codable, Sendable {

    public let method: String

    public let url: String

    public let headers: [String: String]

    public let body: Data?

    public init(
        method: String,
        url: String,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}
