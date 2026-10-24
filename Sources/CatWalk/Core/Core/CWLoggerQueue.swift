//
//  CWLoggerQueue.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

enum CWLoggerQueue {

    static let write = DispatchQueue(
        label: "com.apilogger.write",
        qos: .utility
    )

    static let read = DispatchQueue(
        label: "com.apilogger.read",
        qos: .utility
    )
}
