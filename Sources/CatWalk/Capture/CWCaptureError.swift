//
//  CWCaptureError.swift
//  CatWalk
//

import Foundation

/// Errors raised while intercepting a request.
enum CWCaptureError: LocalizedError {

    /// The request body stream could not be read.
    case bodyStreamReadFailed(underlying: (any Error)?)

    var errorDescription: String? {
        switch self {
        case .bodyStreamReadFailed(let underlying):
            return "Unable to read request body stream. \(underlying?.localizedDescription ?? "")"
        }
    }

    /// Error handed to the app so it sees a familiar failure.
    var clientError: any Error {
        switch self {
        case .bodyStreamReadFailed(let underlying):
            return underlying ?? URLError(.cannotDecodeRawData)
        }
    }
}
