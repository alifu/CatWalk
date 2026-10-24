//
//  CWLogEntry.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

public struct CWLogEntry: Codable, Sendable {

    public let id: UUID

    public let createdAt: Date

    public let level: CWLogLevel

    public let request: CWHTTPRequest

    public let response: CWHTTPResponse?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        level: CWLogLevel = .info,
        request: CWHTTPRequest,
        response: CWHTTPResponse? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.level = level
        self.request = request
        self.response = response
    }
}
