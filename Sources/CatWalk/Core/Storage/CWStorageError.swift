//
//  CWStorageError.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

/// Errors thrown by the storage layer.
public enum CWStorageError: LocalizedError, Sendable {

    /// Failed to create the log directory.
    case directoryCreationFailed

    /// Failed to create the log file.
    case fileCreationFailed

    /// Log file cannot be opened.
    case fileOpenFailed

    /// Unable to write data.
    case writeFailed

    /// Unable to read data.
    case readFailed

    /// Log file is corrupted.
    case corruptedData

    /// Invalid frame format.
    case invalidFrame

    /// Unexpected end of file while reading.
    case unexpectedEOF

    /// Failed to delete log file.
    case deleteFailed

    /// Unknown storage error.
    case unknown(Error)

    public var errorDescription: String? {
        switch self {

        case .directoryCreationFailed:
            return "Unable to create APILogger directory."

        case .fileCreationFailed:
            return "Unable to create log file."

        case .fileOpenFailed:
            return "Unable to open log file."

        case .writeFailed:
            return "Unable to write log."

        case .readFailed:
            return "Unable to read log."

        case .corruptedData:
            return "The log file is corrupted."

        case .invalidFrame:
            return "Invalid log frame."

        case .unexpectedEOF:
            return "Unexpected end of log file."

        case .deleteFailed:
            return "Unable to delete log file."

        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
