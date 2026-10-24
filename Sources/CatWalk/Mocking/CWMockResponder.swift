//
//  CWMockResponder.swift
//  CatWalk
//

import Foundation

/// Builds the Foundation values for a mocked answer.
enum CWMockResponder {

    static func httpResponse(for response: CWMockResponse, url: URL) -> HTTPURLResponse? {
        let headers = response.headers.merging(["Content-Length": String(response.body.count)]) { custom, _ in custom }
        return HTTPURLResponse(url: url, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: headers)
    }
}
