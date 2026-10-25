#if CATWALK_ENABLED
//
//  CWBodyReader.swift
//  CatWalk
//

import Foundation

/// Reads a request body that `URLProtocol` may receive as a stream.
///
/// Inside a protocol `httpBody` is usually `nil` and the body sits in
/// `httpBodyStream`, which can be read only once. The full body is read so it
/// can be forwarded upstream unchanged; capture truncation happens in `CWBody`.
enum CWBodyReader {

    static let chunkSize = 16 * 1024

    static func body(of request: URLRequest) throws(CWCaptureError) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        return try read(stream)
    }

    /// O(size), in `chunkSize` reads.
    static func read(_ stream: InputStream) throws(CWCaptureError) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: chunkSize)

        while true {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count < 0 {
                throw .bodyStreamReadFailed(underlying: stream.streamError)
            }
            if count == 0 {
                return data
            }
            data.append(buffer, count: count)
        }
    }
}
#endif
