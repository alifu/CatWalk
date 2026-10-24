//
//  CWFileRotation.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

final class CWFileRotation {

//    func currentLogFile()
//
//    func rotateIfNeeded()
//
//    func cleanup()
}

final class EncoderPool {

    let encoder = JSONEncoder()

}

protocol LogSerializer {

    func encode(_ entry: CWLogEntry) throws -> Data

    func decode(_ data: Data) throws -> CWLogEntry

}
