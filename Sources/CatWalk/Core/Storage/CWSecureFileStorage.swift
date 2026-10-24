//
//  CWSecureFileStorage.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import Foundation

final class CWSecureFileStorage {

    // MARK: - Properties

    private let crypto: CWCryptoManager

    private let queue = DispatchQueue(
        label: "com.apilogger.storage",
        qos: .utility
    )

    private let fileManager = FileManager.default
    private var writeHandle: FileHandle?
    private let lock = NSLock()

    private let fileName = "logs.bin"

    // MARK: - Init

    init(
        crypto: CWCryptoManager = CWCryptoManager()
    ) {

        self.crypto = crypto

        try? prepareStorage()

    }
    
    deinit {

        close()

    }

}

private extension CWSecureFileStorage {

    var directoryURL: URL {

        let url = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return url
            .appendingPathComponent(
                "APILogger",
                isDirectory: true
            )

    }

}

private extension CWSecureFileStorage {

    var fileURL: URL {

        directoryURL
            .appendingPathComponent(fileName)

    }

}

private extension CWSecureFileStorage {

    func prepareStorage() throws {

        if !fileManager.fileExists(
            atPath: directoryURL.path
        ) {

            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

        }

        if !fileManager.fileExists(
            atPath: fileURL.path
        ) {

            fileManager.createFile(
                atPath: fileURL.path,
                contents: nil
            )

        }

    }

}

private extension CWSecureFileStorage {

    func openFile() throws -> FileHandle {

        guard fileManager.fileExists(
            atPath: fileURL.path
        ) else {

            throw CWStorageError.fileOpenFailed

        }

        return try FileHandle(
            forUpdating: fileURL
        )

    }

}

extension CWSecureFileStorage {

    func append(_ data: Data) throws {

        let encrypted = try crypto.encrypt(data)

        let frame = CWLogFrame(payload: encrypted)

        let encoded = frame.encode()

        lock.lock()
        defer { lock.unlock() }

        let handle = try currentWriteHandle()

        try handle.write(contentsOf: encoded)

        try handle.synchronize()
    }

}

extension CWSecureFileStorage {

    var exists: Bool {

        fileManager.fileExists(
            atPath: fileURL.path
        )

    }

}

extension CWSecureFileStorage {

    var fileSize: UInt64 {

        guard
            let attr = try? fileManager.attributesOfItem(
                atPath: fileURL.path
            ),
            let size = attr[
                .size
            ] as? UInt64
        else {

            return 0

        }

        return size

    }

}

extension CWSecureFileStorage {

    func readAll() throws -> [Data] {

        guard exists else {
            return []
        }

        let handle = try FileHandle(forReadingFrom: fileURL)

        defer {
            try? handle.close()
        }

        var result: [Data] = []

        while true {

            guard let frame = try CWLogFrame.decode(from: handle) else {
                break
            }

            let decrypted = try crypto.decrypt(frame.payload)

            result.append(decrypted)
        }

        return result
    }

}

extension CWSecureFileStorage {

    func readFirst() throws -> Data? {

        let all = try readAll()

        return all.first

    }

}

extension CWSecureFileStorage {

    func readLast() throws -> Data? {

        let all = try readAll()

        return all.last

    }

}

extension CWSecureFileStorage {

    var count: Int {

        (try? readAll().count) ?? 0

    }

}

extension CWSecureFileStorage {

    var isEmpty: Bool {

        count == 0

    }

}

private extension CWSecureFileStorage {

    func currentWriteHandle() throws -> FileHandle {

        lock.lock()
        defer { lock.unlock() }

        if let handle = writeHandle {
            return handle
        }

        let handle = try FileHandle(forUpdating: fileURL)

        try handle.seekToEnd()

        writeHandle = handle

        return handle
    }

}

extension CWSecureFileStorage {

    func close() {

        lock.lock()
        defer { lock.unlock() }

        try? writeHandle?.close()

        writeHandle = nil
    }

}

extension CWSecureFileStorage {

    func removeAll() throws {

        lock.lock()
        defer { lock.unlock() }

        try? writeHandle?.close()
        writeHandle = nil

        if fileManager.fileExists(atPath: fileURL.path) {

            try fileManager.removeItem(at: fileURL)

        }

        fileManager.createFile(
            atPath: fileURL.path,
            contents: nil
        )
    }

}

extension CWSecureFileStorage {

    func reset() throws {

        try removeAll()

        try crypto.reset()

    }

}

extension CWSecureFileStorage {

    func flush() throws {

        lock.lock()
        defer { lock.unlock() }

        try writeHandle?.synchronize()
    }

}
