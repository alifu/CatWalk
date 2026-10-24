//
//  CWAPILogger.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

@MainActor
public final class CWAPILogger {

    public static let shared = CWAPILogger()

    public var configuration: CWConfiguration

    private init(
        configuration: CWConfiguration = .default
    ) {
        self.configuration = configuration
    }

    private static var started = false
    
    public static func start() {
        guard !started else { return }
        started = true
        
        SecureFileStorage.shared.deleteAllLogs()
        URLProtocol.registerClass(APILoggerURLProtocol.self)
    }
    
    public static func stop() {
        guard started else { return }
        started = false
        
        URLProtocol.unregisterClass(APILoggerURLProtocol.self)
    }

    public func log(
        request: CWHTTPRequest,
        response: CWHTTPResponse?,
        level: CWLogLevel = .info
    ) {

        guard configuration.enabled else {
            return
        }

        let entry = CWLogEntry(
            level: level,
            request: request,
            response: response
        )
    }
}
