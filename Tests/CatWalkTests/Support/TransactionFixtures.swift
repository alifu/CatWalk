#if CATWALK_ENABLED
//
//  TransactionFixtures.swift
//  CatWalk
//

import Foundation
@testable import CatWalk

/// Finished transactions built through the real recorder.
enum TransactionFixtures {

    static func make(
        _ method: String = "GET",
        _ url: String = "https://api.test/items",
        status: Int? = 200,
        responseBody: Data? = nil,
        mimeType: String = "application/json",
        requestBody: Data? = nil,
        headers: [String: String] = [:],
        error: URLError.Code? = nil
    ) -> CWTransaction {
        let recorder = CWRecorder(configuration: CWConfiguration(redactedHeaders: []))
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let begun = recorder.begin(request, body: requestBody)!
        guard let status else {
            return error.map { recorder.complete(begun, response: nil, body: nil, error: URLError($0)) } ?? begun
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mimeType]
        )
        return recorder.complete(
            begun, response: response,
            body: responseBody.map { CWBody(capturing: $0, limit: 1 << 20) }, error: nil
        )
    }
}
#endif
