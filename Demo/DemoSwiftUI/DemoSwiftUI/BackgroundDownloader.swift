//
//  BackgroundDownloader.swift
//  DemoSwiftUI
//

import Foundation
import os

/// Downloads through a background `URLSession`, which `URLProtocol` never sees.
/// CatWalk shows these rows with a "BG" chip once they finish.
final class BackgroundDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    static let shared = BackgroundDownloader()

    private static let logger = Logger(subsystem: "CatWalk.DemoSwiftUI", category: "background")

    private lazy var session = URLSession(
        configuration: .background(withIdentifier: "CatWalk.DemoSwiftUI.background"),
        delegate: self,
        delegateQueue: nil
    )

    func download() {
        session.downloadTask(with: URL(string: "https://dummyjson.com/products/1")!).resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let size = (try? Data(contentsOf: location))?.count ?? 0
        Self.logger.info("Background download finished: \(size) bytes")
    }
}
