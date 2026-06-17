//
//  ExifToolRunner.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 17/06/2026.
//

import Foundation

/// Runtime configuration shared by ExifTool process runners.
nonisolated struct ExifToolRuntime {
    let perlURL: URL
    let exiftoolURL: URL
    let workingDirectoryURL: URL
    let environment: [String: String]
}

/// Executes ExifTool arguments and returns raw standard output.
nonisolated protocol ExifToolRunner: AnyObject {
    func run(arguments: [String]) throws -> Data
}

/// Classic runner: starts one ExifTool process for each request.
nonisolated final class ProcessPerFileExifToolRunner: ExifToolRunner {
    private let runtime: ExifToolRuntime

    init(runtime: ExifToolRuntime) {
        self.runtime = runtime
    }

    func run(arguments: [String]) throws -> Data {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = runtime.perlURL
        process.arguments = [runtime.exiftoolURL.path] + arguments
        process.currentDirectoryURL = runtime.workingDirectoryURL
        process.environment = runtime.environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw ExifToolError.processLaunchFailed(
                path: runtime.perlURL.path,
                message: error.localizedDescription
            )
        }

        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw ExifToolError.processFailed(
                exitCode: process.terminationStatus,
                message: errorMessage.isEmpty ? "No error message was provided." : errorMessage
            )
        }

        guard !outputData.isEmpty else {
            throw ExifToolError.emptyOutput
        }

        return outputData
    }
}

/// Errors specific to the persistent ExifTool runner.
enum PersistentExifToolRunnerError: Error, LocalizedError {
    case processNotRunning
    case responseTimeout(seconds: TimeInterval)
    case processLaunchFailed(path: String, message: String)
    case writeFailed(message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .processNotRunning:
            return "Persistent ExifTool process is not running."
        case .responseTimeout(let seconds):
            return "Persistent ExifTool response timed out after \(seconds)s."
        case .processLaunchFailed(let path, let message):
            return "Could not launch persistent ExifTool at \(path): \(message)"
        case .writeFailed(let message):
            return "Could not write to persistent ExifTool: \(message)"
        case .emptyResponse:
            return "Persistent ExifTool completed a request without output."
        }
    }
}

/// Persistent runner using ExifTool's `-stay_open True -@ -` protocol.
///
/// This first implementation is intentionally sequential: one request is written
/// and read to completion before the next request is allowed.
nonisolated final class PersistentExifToolRunner: ExifToolRunner, @unchecked Sendable {
    private enum Configuration {
        static let responseTimeout: TimeInterval = 30
        static let shutdownTimeout: TimeInterval = 2
        static let shutdownPollInterval: TimeInterval = 0.02
    }

    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Data, Error>?

        func set(_ result: Result<Data, Error>) {
            lock.lock()
            self.result = result
            lock.unlock()
        }

        func get() -> Result<Data, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    private let runtime: ExifToolRuntime
    private let responseTimeout: TimeInterval
    private let process = Process()
    private let standardInput = Pipe()
    private let standardOutput = Pipe()
    private let standardError = Pipe()
    private let requestLock = NSLock()
    private let stateLock = NSLock()
    private let ioQueue = DispatchQueue(label: "PhotoAnalyzer.PersistentExifToolRunner.io")
    private var requestID = 0
    private var isClosed = false
    private var stderrBuffer = Data()

    init(runtime: ExifToolRuntime, responseTimeout: TimeInterval = Configuration.responseTimeout) throws {
        self.runtime = runtime
        self.responseTimeout = responseTimeout
        try start()
    }

    deinit {
        close()
    }

    func run(arguments: [String]) throws -> Data {
        requestLock.lock()
        defer { requestLock.unlock() }

        guard isProcessAvailable else {
            throw PersistentExifToolRunnerError.processNotRunning
        }

        requestID += 1
        let currentRequestID = requestID
        let readyMarker = "{ready\(currentRequestID)}"
        let resultBox = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)

        ioQueue.async { [standardInput, standardOutput] in
            do {
                try self.write(
                    arguments: arguments,
                    requestID: currentRequestID,
                    to: standardInput.fileHandleForWriting
                )
                let response = try self.readResponse(
                    from: standardOutput.fileHandleForReading,
                    untilReadyMarker: readyMarker
                )
                resultBox.set(.success(response))
            } catch {
                resultBox.set(.failure(error))
            }

            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + responseTimeout) == .timedOut {
            close()
            throw PersistentExifToolRunnerError.responseTimeout(seconds: responseTimeout)
        }

        guard let result = resultBox.get() else {
            close()
            throw PersistentExifToolRunnerError.emptyResponse
        }

        let data = try result.get()

        guard !data.isEmpty else {
            throw PersistentExifToolRunnerError.emptyResponse
        }

        return data
    }

    func close() {
        stateLock.lock()
        guard !isClosed else {
            stateLock.unlock()
            return
        }
        isClosed = true
        stateLock.unlock()

        standardError.fileHandleForReading.readabilityHandler = nil

        if process.isRunning {
            let shutdownData = Data("-stay_open\nFalse\n".utf8)
            try? standardInput.fileHandleForWriting.write(contentsOf: shutdownData)
            try? standardInput.fileHandleForWriting.close()

            let deadline = Date().addingTimeInterval(Configuration.shutdownTimeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: Configuration.shutdownPollInterval)
            }

            if process.isRunning {
                process.terminate()
            }
        }
    }

    private var isProcessAvailable: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return !isClosed && process.isRunning
    }

    private func start() throws {
        process.executableURL = runtime.perlURL
        process.arguments = [
            runtime.exiftoolURL.path,
            "-stay_open",
            "True",
            "-@",
            "-"
        ]
        process.currentDirectoryURL = runtime.workingDirectoryURL
        process.environment = runtime.environment
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError

        standardError.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }

            self?.stateLock.lock()
            self?.stderrBuffer.append(data)
            self?.stateLock.unlock()
        }

        do {
            try process.run()
        } catch {
            throw PersistentExifToolRunnerError.processLaunchFailed(
                path: runtime.perlURL.path,
                message: error.localizedDescription
            )
        }
    }

    private func write(arguments: [String], requestID: Int, to handle: FileHandle) throws {
        let request = (arguments + ["-execute\(requestID)"]).joined(separator: "\n") + "\n"

        do {
            try handle.write(contentsOf: Data(request.utf8))
        } catch {
            throw PersistentExifToolRunnerError.writeFailed(message: error.localizedDescription)
        }
    }

    private func readResponse(from handle: FileHandle, untilReadyMarker readyMarker: String) throws -> Data {
        let readyMarkerData = Data(readyMarker.utf8)
        var response = Data()

        while true {
            let byte = handle.readData(ofLength: 1)

            guard !byte.isEmpty else {
                throw PersistentExifToolRunnerError.processNotRunning
            }

            response.append(byte)

            if response.count >= readyMarkerData.count,
               response.suffix(readyMarkerData.count).elementsEqual(readyMarkerData) {
                response.removeLast(readyMarkerData.count)
                trimTrailingWhitespaceAndNewlines(from: &response)
                return response
            }
        }
    }

    private func trimTrailingWhitespaceAndNewlines(from data: inout Data) {
        while let lastByte = data.last,
              lastByte == 10 || lastByte == 13 || lastByte == 32 || lastByte == 9 {
            data.removeLast()
        }
    }
}
