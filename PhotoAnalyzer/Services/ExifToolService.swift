//
//  ExifToolService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import Foundation

/// Errors produced while validating or running ExifTool.
enum ExifToolError: Error, LocalizedError {
    /// ExifTool was not found in the application bundle.
    case bundledExecutableNotFound(resourceName: String)

    /// The bundled ExifTool `lib` directory was not found next to the script.
    case bundledLibraryNotFound(path: String)

    /// The Perl interpreter was not found at the configured path.
    case perlNotFound(path: String)

    /// ExifTool terminated with a non-zero exit code.
    case processFailed(exitCode: Int32, message: String)

    /// ExifTool could not be launched by `Process`.
    case processLaunchFailed(path: String, message: String)

    /// ExifTool completed without producing standard output.
    case emptyOutput

    /// ExifTool returned an empty metadata array.
    case emptyMetadata

    /// A readable error description for UI and log output.
    var errorDescription: String? {
        switch self {
        case .bundledExecutableNotFound(let resourceName):
            return "ExifTool resource \"\(resourceName)\" was not found in the application bundle."
        case .bundledLibraryNotFound(let path):
            return "ExifTool library folder was not found at \(path). Add Exiftool as a folder reference so its lib directory is preserved."
        case .perlNotFound(let path):
            return "Perl was not found at \(path)."
        case .processFailed(let exitCode, let message):
            return "ExifTool failed with exit code \(exitCode): \(message)"
        case .processLaunchFailed(let path, let message):
            return "Could not launch ExifTool at \(path): \(message)"
        case .emptyOutput:
            return "ExifTool completed but produced no output."
        case .emptyMetadata:
            return "ExifTool returned no metadata for this file."
        }
    }
}

/// A service responsible only for running bundled ExifTool and returning its raw output.
final class ExifToolService {
    /// The ExifTool script resource name expected in the application bundle.
    private let executableResourceName = "exiftool"

    /// Bundle subdirectories that may contain the ExifTool script and its `lib` folder.
    private let executableResourceSubdirectories = ["Exiftool", "Resources/Exiftool"]

    /// The system Perl interpreter used to run the bundled ExifTool script.
    private let perlPath = "/usr/bin/perl"

    /// Creates an ExifTool service.
    nonisolated init() {}

    /// Runs bundled ExifTool with `-ver` and returns its version string.
    /// - Returns: The ExifTool version reported by the bundled script.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func version() throws -> String {
        let exiftoolURL = try bundledExifToolURL()
        let output = try runExifTool(at: exiftoolURL, arguments: ["-ver"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs bundled ExifTool recursively on a folder and returns the raw JSON output.
    /// - Parameter folderURL: The folder URL to analyze.
    /// - Returns: Raw JSON data produced by ExifTool.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func analyzeFolder(at folderURL: URL) throws -> Data {
        let exiftoolURL = try bundledExifToolURL()
        return try runExifToolData(at: exiftoolURL, arguments: ["-json", "-r", folderURL.path])
    }

    /// Runs bundled ExifTool on a single file and returns decoded metadata.
    /// - Parameter fileURL: The file URL to analyze.
    /// - Returns: The first metadata object produced by ExifTool, or `nil` when no metadata is available.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func extractMetadata(from fileURL: URL) throws -> ExifToolMetadata? {
        let exiftoolURL = try bundledExifToolURL()
        let arguments = ExifToolTagWhitelist.arguments + [fileURL.path]
        let data = try runExifToolData(
            at: exiftoolURL,
            arguments: arguments
        )
        let metadata = try JSONDecoder().decode([ExifToolMetadata].self, from: data)
        return metadata.first
    }

    /// Runs bundled ExifTool on a single file and returns grouped export metadata.
    /// - Parameter fileURL: The file URL to analyze.
    /// - Returns: The first export metadata object produced by ExifTool, or `nil` when no metadata is available.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func extractExportMetadata(from fileURL: URL) throws -> ExportPhotoMetadata? {
        let exiftoolURL = try bundledExifToolURL()
        let arguments = ExifToolTagWhitelist.exportArguments + [fileURL.path]
        let data = try runExifToolData(
            at: exiftoolURL,
            arguments: arguments
        )
        let metadata = try JSONDecoder().decode([ExportPhotoMetadata].self, from: data)
        return metadata.first
    }

    /// Returns the bundled ExifTool script path after checking that it exists in the app bundle.
    /// - Returns: The bundled ExifTool script path.
    /// - Throws: `ExifToolError` when the resource is missing.
    nonisolated func validatedExecutablePath() throws -> String {
        try bundledExifToolURL().path
    }

    /// Resolves the bundled ExifTool script URL and validates the Perl interpreter path.
    /// - Returns: The URL for the bundled ExifTool script.
    /// - Throws: `ExifToolError` when ExifTool or Perl cannot be found.
    nonisolated private func bundledExifToolURL() throws -> URL {
        guard FileManager.default.fileExists(atPath: perlPath) else {
            throw ExifToolError.perlNotFound(path: perlPath)
        }

        let exiftoolURL = bundledExifToolURLFromKnownLocations()

        guard let exiftoolURL else {
            throw ExifToolError.bundledExecutableNotFound(resourceName: executableResourceName)
        }

        return exiftoolURL
    }

    /// Searches the bundle locations where the ExifTool folder may be copied.
    /// - Returns: The first matching bundled ExifTool script URL, or `nil` when none exists.
    nonisolated private func bundledExifToolURLFromKnownLocations() -> URL? {
        for subdirectory in executableResourceSubdirectories {
            if let exiftoolURL = Bundle.main.url(
                forResource: executableResourceName,
                withExtension: nil,
                subdirectory: subdirectory
            ) {
                return exiftoolURL
            }
        }

        return Bundle.main.url(forResource: executableResourceName, withExtension: nil)
    }

    /// Runs bundled ExifTool and decodes standard output as UTF-8 text.
    /// - Parameters:
    ///   - exiftoolURL: The bundled ExifTool script URL.
    ///   - arguments: The command-line arguments passed to ExifTool.
    /// - Returns: Standard output decoded as text.
    /// - Throws: `ExifToolError` when the process fails or output is empty.
    nonisolated private func runExifTool(at exiftoolURL: URL, arguments: [String]) throws -> String {
        let outputData = try runExifToolData(at: exiftoolURL, arguments: arguments)
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    /// Runs bundled ExifTool through Perl and returns standard output as raw data.
    /// - Parameters:
    ///   - exiftoolURL: The bundled ExifTool script URL.
    ///   - arguments: The command-line arguments passed to ExifTool.
    /// - Returns: Standard output data.
    /// - Throws: `ExifToolError` when the process fails or output is empty.
    nonisolated private func runExifToolData(at exiftoolURL: URL, arguments: [String]) throws -> Data {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        let exiftoolDirectoryURL = exiftoolURL.deletingLastPathComponent()
        let exiftoolLibraryURL = exiftoolDirectoryURL.appendingPathComponent("lib", isDirectory: true)

        guard FileManager.default.fileExists(atPath: exiftoolLibraryURL.path) else {
            throw ExifToolError.bundledLibraryNotFound(path: exiftoolLibraryURL.path)
        }

        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = [exiftoolURL.path] + arguments
        process.currentDirectoryURL = exiftoolDirectoryURL
        process.environment = processEnvironment(perlLibraryURL: exiftoolLibraryURL)
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw ExifToolError.processLaunchFailed(
                path: perlPath,
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

    /// Builds a process environment that points Perl to the bundled ExifTool library folder.
    /// - Parameter perlLibraryURL: The bundled ExifTool `lib` directory URL.
    /// - Returns: A process environment including `PERL5LIB`.
    nonisolated private func processEnvironment(perlLibraryURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPerlLibraryPath = environment["PERL5LIB"]

        if let existingPerlLibraryPath, !existingPerlLibraryPath.isEmpty {
            environment["PERL5LIB"] = "\(perlLibraryURL.path):\(existingPerlLibraryPath)"
        } else {
            environment["PERL5LIB"] = perlLibraryURL.path
        }

        return environment
    }
}
