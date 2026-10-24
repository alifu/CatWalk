//
//  CWConfiguration.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

public struct CWConfiguration: Sendable {

    public var enabled: Bool

    public var minimumLevel: CWLogLevel

    public var maximumFileSize: UInt64

    public var maximumFileCount: Int

    public var prettyPrintJSON: Bool

    public var logRequestBody: Bool

    public var logResponseBody: Bool

    public var logHeaders: Bool

    public init(
        enabled: Bool = true,
        minimumLevel: CWLogLevel = .debug,
        maximumFileSize: UInt64 = 10 * 1024 * 1024,
        maximumFileCount: Int = 5,
        prettyPrintJSON: Bool = true,
        logRequestBody: Bool = true,
        logResponseBody: Bool = true,
        logHeaders: Bool = true
    ) {
        self.enabled = enabled
        self.minimumLevel = minimumLevel
        self.maximumFileSize = maximumFileSize
        self.maximumFileCount = maximumFileCount
        self.prettyPrintJSON = prettyPrintJSON
        self.logRequestBody = logRequestBody
        self.logResponseBody = logResponseBody
        self.logHeaders = logHeaders
    }

    public static let `default` = CWConfiguration()
}
