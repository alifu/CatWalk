//
//  CWEncryptionKeyProvider.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import CryptoKit

@MainActor
protocol CWEncryptionKeyProvider {

    func loadKey() throws -> SymmetricKey
}
