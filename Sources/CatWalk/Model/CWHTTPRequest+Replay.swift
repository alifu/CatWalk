//
//  CWHTTPRequest+Replay.swift
//  CatWalk
//

import Foundation

extension CWHTTPRequest {

    /// A request that repeats this one. Redacted header values are left out (they are not the
    /// real secrets) and a truncated body is not sent.
    var replayRequest: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.entries
            .filter { $0.value != CWRedaction.placeholder }
            .forEach { request.setValue($0.value, forHTTPHeaderField: $0.name) }
        if let body, !body.isTruncated, !body.data.isEmpty {
            request.httpBody = body.data
        }
        return request
    }
}
