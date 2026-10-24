//
//  CWCryptoError.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

/// Errors thrown by the cryptography layer.
public enum CWCryptoError: LocalizedError, Sendable {

    // MARK: - Key Management

    /// Failed to generate a new encryption key.
    case keyGenerationFailed

    /// Encryption key does not exist.
    case keyNotFound

    /// Failed to save key into Keychain.
    case keySaveFailed(OSStatus)

    /// Failed to read key from Keychain.
    case keyReadFailed(OSStatus)

    /// Failed to delete key from Keychain.
    case keyDeleteFailed(OSStatus)

    // MARK: - Encryption

    /// Failed to encrypt data.
    case encryptionFailed(Error)

    /// Failed to decrypt data.
    case decryptionFailed(Error)

    // MARK: - Data

    /// Encrypted payload is invalid.
    case invalidEncryptedData

    /// Authentication failed.
    /// Usually means the file was modified or the key is incorrect.
    case authenticationFailed

    /// Unknown cryptography error.
    case unknown(Error)

    public var errorDescription: String? {

        switch self {

        case .keyGenerationFailed:
            return "Unable to generate encryption key."

        case .keyNotFound:
            return "Encryption key not found."

        case .keySaveFailed(let status):
            return "Unable to save encryption key. OSStatus: \(status)"

        case .keyReadFailed(let status):
            return "Unable to read encryption key. OSStatus: \(status)"

        case .keyDeleteFailed(let status):
            return "Unable to delete encryption key. OSStatus: \(status)"

        case .encryptionFailed(let error):
            return "Encryption failed. \(error.localizedDescription)"

        case .decryptionFailed(let error):
            return "Decryption failed. \(error.localizedDescription)"

        case .invalidEncryptedData:
            return "Encrypted payload is invalid."

        case .authenticationFailed:
            return "Authentication failed."

        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
