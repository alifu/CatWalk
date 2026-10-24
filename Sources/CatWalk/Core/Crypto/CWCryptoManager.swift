//
//  CWCryptoManager.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation
import CryptoKit

final class CWCryptoManager {

    private let keyStore: CWKeyStore

    /// Cached symmetric key.
    private var cachedKey: SymmetricKey?

    /// Thread safety.
    private let lock = NSLock()

    init(
        keyStore: CWKeyStore = CWKeychainManager()
    ) {
        self.keyStore = keyStore
    }

}

private extension CWCryptoManager {

    func currentKey() throws -> SymmetricKey {

        lock.lock()
        defer { lock.unlock() }

        if let key = cachedKey {
            return key
        }

        let key: SymmetricKey

        if keyStore.exists() {

            let data = try keyStore.load()

            key = SymmetricKey(data: data)

        } else {

            key = SymmetricKey(size: .bits256)

            let data = key.withUnsafeBytes {

                Data($0)

            }

            try keyStore.save(data)
        }

        cachedKey = key

        return key
    }

}

extension CWCryptoManager {

    func encrypt(
        _ data: Data
    ) throws -> Data {

        do {

            let key = try currentKey()

            let sealed = try AES.GCM.seal(
                data,
                using: key
            )

            guard let combined = sealed.combined else {

                throw CWCryptoError.invalidEncryptedData

            }

            return combined

        } catch let error as CWCryptoError {

            throw error

        } catch {

            throw CWCryptoError.encryptionFailed(error)

        }

    }

}

extension CWCryptoManager {

    func decrypt(
        _ encrypted: Data
    ) throws -> Data {

        do {

            let key = try currentKey()

            let sealed = try AES.GCM.SealedBox(
                combined: encrypted
            )

            return try AES.GCM.open(
                sealed,
                using: key
            )

        } catch let error as CWCryptoError {
            throw error
        } catch let cryptoError as CryptoKitError {
            switch cryptoError {
            case .authenticationFailure:
                throw CWCryptoError.authenticationFailed
            default:
                throw CWCryptoError.decryptionFailed(cryptoError)
            }
        } catch {
            throw CWCryptoError.decryptionFailed(error)
        }

    }

}

extension CWCryptoManager {

    func reset() throws {

        lock.lock()
        defer { lock.unlock() }

        cachedKey = nil

        try keyStore.delete()

    }

}
