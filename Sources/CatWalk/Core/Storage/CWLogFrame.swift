//
//  CWLogFrame.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

struct CWLogFrame {

    /// Length of encrypted payload.
    let length: UInt32

    /// AES-GCM encrypted payload.
    let payload: Data

}

extension CWLogFrame {

    init(payload: Data) {

        self.length = UInt32(payload.count)

        self.payload = payload
    }

}

extension CWLogFrame {

    func encode() -> Data {

        var data = Data()

        var length = self.length.bigEndian

        withUnsafeBytes(of: &length) {

            data.append(contentsOf: $0)

        }

        data.append(payload)

        return data
    }

}

extension CWLogFrame {

    static func decode(
        from handle: FileHandle
    ) throws -> CWLogFrame? {

        let lengthData = try handle.read(
            upToCount: 4
        )

        guard
            let lengthData,
            !lengthData.isEmpty
        else {

            return nil

        }

        guard lengthData.count == 4 else {

            throw CWStorageError.unexpectedEOF

        }

        let length = lengthData.withUnsafeBytes {

            $0.load(as: UInt32.self).bigEndian

        }

        let payload = try handle.read(
            upToCount: Int(length)
        )

        guard let payload else {

            throw CWStorageError.unexpectedEOF

        }

        guard payload.count == Int(length) else {

            throw CWStorageError.unexpectedEOF

        }

        return CWLogFrame(
            length: length,
            payload: payload
        )
    }

}
