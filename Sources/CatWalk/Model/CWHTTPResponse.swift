//
//  CWHTTPResponse.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

/// A captured HTTP response.
public struct CWHTTPResponse: Sendable, Equatable {

    public let statusCode: Int

    /// Headers after redaction.
    public let headers: CWHeaders

    /// `nil` when the response had no body.
    public let body: CWBody?

    public let mimeType: String?

    init(
        statusCode: Int,
        headers: CWHeaders,
        body: CWBody?,
        mimeType: String?
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.mimeType = mimeType
    }
}
