//
//  CWLogLevel.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

import Foundation

public enum CWLogLevel: Int, Codable, Sendable {

    case debug
    case info
    case warning
    case error

    public var name: String {
        switch self {
        case .debug:
            return "DEBUG"

        case .info:
            return "INFO"

        case .warning:
            return "WARNING"

        case .error:
            return "ERROR"
        }
    }
}
