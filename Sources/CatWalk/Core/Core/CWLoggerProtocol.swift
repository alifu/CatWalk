//
//  CWLoggerProtocol.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

protocol CWLoggerProtocol {

    func log(_ entry: CWLogEntry)
}

@MainActor
final class APILoggerURLProtocol: URLProtocol {

    private static let handledKey = "APILoggerHandled"

    internal var dataTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {

        if URLProtocol.property(
            forKey: handledKey,
            in: request
        ) != nil {
            return false
        }

        return true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {

        let id = UUID()

        APILoggerRecorder.shared.begin(
            id: id,
            request: request
        )

        let mutableRequest = ((request as NSURLRequest).mutableCopy()
                                as? NSMutableURLRequest)!

        URLProtocol.setProperty(
            true,
            forKey: Self.handledKey,
            in: mutableRequest
        )

        let configuration = URLSessionConfiguration.default

        configuration.protocolClasses = configuration.protocolClasses?
            .filter {
                $0 != APILoggerURLProtocol.self
            }

        let session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: nil
        )

        dataTask = session.dataTask(with: mutableRequest as URLRequest) {
            [weak self] data,
            response,
            error in

            guard let self else { return }

            APILoggerRecorder.shared.finish(
                id: id,
                response: response,
                data: data,
                error: error
            )

            if let response {
                self.client?.urlProtocol(
                    self,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
            }

            if let data {
                self.client?.urlProtocol(
                    self,
                    didLoad: data
                )
            }

            if let error {
                self.client?.urlProtocol(
                    self,
                    didFailWithError: error
                )
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }

        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
    }
}

@MainActor
final class APILoggerRecorder {

    static let shared = APILoggerRecorder()

    private let queue = DispatchQueue(
        label: "com.apilogger.recorder"
    )

    private var logs: [UUID: APILogModel] = [:]

    func begin(
        id: UUID,
        request: URLRequest
    ) {

        queue.async {

            self.logs[id] = APILogModel(
                id: id,
                url: request.url?.absoluteString ?? "",
                method: request.httpMethod ?? "",
                requestHeaders: request.allHTTPHeaderFields ?? [:],
                requestBody: request.httpBody,
                startTime: Date()
            )
        }
    }

    func finish(
        id: UUID,
        response: URLResponse?,
        data: Data?,
        error: Error?
    ) {

        queue.async {

            guard var log = self.logs[id] else { return }

            if let http = response as? HTTPURLResponse {
                log.statusCode = http.statusCode

                var headers: [String: String] = [:]
                http.allHeaderFields.forEach { key, value in
                    let keyString = String(describing: key)
                    let valueString = String(describing: value)
                    headers[keyString] = valueString
                }
                log.responseHeaders = headers
            }

            log.responseBody = data
            log.error = error?.localizedDescription
            log.endTime = Date()

            SecureFileStorage.shared.save(log)

            self.logs.removeValue(forKey: id)
        }
    }
}

@MainActor
final class SecureFileStorage {

    static let shared = SecureFileStorage()

    private let queue = DispatchQueue(
        label: "com.apilogger.storage"
    )

    // MARK: - Save

    func save(_ log: APILogModel) {

        queue.async {

            do {

                let data = try JSONEncoder().encode(log)

                let directory = self.logDirectory()

                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )

                let file = directory
                    .appendingPathComponent(log.id.uuidString)
                    .appendingPathExtension("json")

                try data.write(to: file)

            } catch {

            }
        }
    }

    // MARK: - Get All Logs

    func fetchAllLogs() -> [APILogModel] {

        queue.sync {

            let directory = logDirectory()

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            let decoder = JSONDecoder()

            var logs: [APILogModel] = []

            for file in files where file.pathExtension == "json" {

                guard
                    let data = try? Data(contentsOf: file),
                    let log = try? decoder.decode(APILogModel.self, from: data)
                else {
                    continue
                }

                logs.append(log)
            }

            return logs.sorted {
                ($0.startTime) > ($1.startTime)
            }
        }
    }

    // MARK: - Get Single Log

    func fetchLog(id: UUID) -> APILogModel? {

        queue.sync {

            let file = logDirectory()
                .appendingPathComponent(id.uuidString)
                .appendingPathExtension("json")

            guard
                let data = try? Data(contentsOf: file)
            else {
                return nil
            }

            return try? JSONDecoder().decode(
                APILogModel.self,
                from: data
            )
        }
    }

    // MARK: - Delete

    func deleteLog(id: UUID) {

        queue.async {

            let file = self.logDirectory()
                .appendingPathComponent(id.uuidString)
                .appendingPathExtension("json")

            try? FileManager.default.removeItem(at: file)
        }
    }

    func deleteAllLogs() {

        queue.async {

            let directory = self.logDirectory()

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                return
            }

            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Count

    func count() -> Int {

        queue.sync {

            let directory = logDirectory()

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                return 0
            }

            return files.filter {
                $0.pathExtension == "json"
            }.count
        }
    }

    // MARK: - Directory

    private func logDirectory() -> URL {

        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("APILogger")
    }
}

struct APILogModel: Codable {

    let id: UUID
    let url: String
    let method: String
    let requestHeaders: [String: String]
    let requestBody: Data?
    let startTime: Date
    var endTime: Date?
    var statusCode: Int?

    // Use String:String for headers to ensure Codable compliance
    var responseHeaders: [String: String] = [:]

    var responseBody: Data?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case method
        case requestHeaders
        case requestBody
        case startTime
        case endTime
        case statusCode
        case responseHeaders
        case responseBody
        case error
    }

    init(
        id: UUID,
        url: String,
        method: String,
        requestHeaders: [String: String],
        requestBody: Data?,
        startTime: Date,
        endTime: Date? = nil,
        statusCode: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: Data? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.startTime = startTime
        self.endTime = endTime
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.error = error
    }
}
