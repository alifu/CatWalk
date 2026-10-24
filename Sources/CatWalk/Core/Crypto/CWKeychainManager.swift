//
//  CWKeychainManager.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation
import CryptoKit
import Security

protocol CWKeyStore {

    /// Save raw key data.
    func save(_ key: Data) throws

    /// Load raw key data.
    func load() throws -> Data

    /// Delete key.
    func delete() throws

    /// Returns true if key exists.
    func exists() -> Bool
}

final class CWKeychainManager: CWKeyStore {

    // MARK: - Properties

    private let service: String
    private let account: String

    private let lock = NSRecursiveLock()

    // MARK: - Init

    init(
        service: String = "com.apilogger.crypto",
        account: String = "master_key"
    ) {
        self.service = service
        self.account = account
    }
}

private extension CWKeychainManager {

    var query: [CFString: Any] {

        [
            kSecClass: kSecClassGenericPassword,

            kSecAttrService: service,

            kSecAttrAccount: account
        ]
    }

}

extension CWKeychainManager {

    func save(_ key: Data) throws {

        lock.lock()
        defer { lock.unlock() }

        try? delete()

        var query = self.query

        query[kSecValueData] = key

        query[kSecAttrAccessible] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        guard status == errSecSuccess else {

            throw CWCryptoError.keySaveFailed(status)

        }
    }

}

extension CWKeychainManager {

    func load() throws -> Data {

        lock.lock()
        defer { lock.unlock() }

        var query = self.query

        query[kSecReturnData] = true

        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        guard status == errSecSuccess else {

            throw CWCryptoError.keyReadFailed(status)

        }

        guard let data = result as? Data else {

            throw CWCryptoError.keyNotFound

        }

        return data
    }

}

extension CWKeychainManager {

    func delete() throws {

        lock.lock()
        defer { lock.unlock() }

        let status = SecItemDelete(
            query as CFDictionary
        )

        guard
            status == errSecSuccess ||
            status == errSecItemNotFound
        else {

            throw CWCryptoError.keyDeleteFailed(status)

        }
    }

}

extension CWKeychainManager {

    func exists() -> Bool {

        var query = self.query

        query[kSecReturnAttributes] = true

        query[kSecMatchLimit] = kSecMatchLimitOne

        let status = SecItemCopyMatching(
            query as CFDictionary,
            nil
        )

        return status == errSecSuccess
    }

}
