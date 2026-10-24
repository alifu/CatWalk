#if CATWALK_ENABLED
//
//  CWTransactionError.swift
//  CatWalk
//

import Foundation

/// Value snapshot of the error a request failed with.
public struct CWTransactionError: Sendable, Equatable {

    public let domain: String

    public let code: Int

    public let message: String

    init(_ error: any Error) {
        let nsError = error as NSError
        self.domain = nsError.domain
        self.code = nsError.code
        self.message = nsError.localizedDescription
    }
}
#endif
