//
//  CWHTTPResponse.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

public struct CWHTTPResponse: Codable, Sendable {

    public let statusCode: Int?

    public let headers: [String: String]

    public let body: Data?

    public let duration: TimeInterval?

    public let errorDescription: String?

    public init(
        statusCode: Int?,
        headers: [String: String] = [:],
        body: Data? = nil,
        duration: TimeInterval? = nil,
        errorDescription: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.duration = duration
        self.errorDescription = errorDescription
    }
}
