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
        let outputData = try makeProcessPerFileRunner().run(arguments: ["-ver"])
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs bundled ExifTool recursively on a folder and returns the raw JSON output.
    /// - Parameter folderURL: The folder URL to analyze.
    /// - Returns: Raw JSON data produced by ExifTool.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func analyzeFolder(at folderURL: URL) throws -> Data {
        try makeProcessPerFileRunner().run(arguments: ["-json", "-r", folderURL.path])
    }

    /// Runs bundled ExifTool once for analysis and AI package export metadata.
    /// - Parameter fileURL: The file URL to analyze.
    /// - Returns: The first unified metadata object produced by ExifTool, or `nil` when no metadata is available.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func extractAnalysisMetadata(from fileURL: URL) throws -> ExportPhotoMetadata? {
        try extractAnalysisMetadata(from: fileURL, using: makeProcessPerFileRunner())
    }

    /// Runs analysis metadata extraction using a caller-provided runner.
    /// - Parameters:
    ///   - fileURL: The file URL to analyze.
    ///   - runner: The ExifTool runner to use for this request.
    /// - Returns: The first unified metadata object produced by ExifTool, or `nil` when no metadata is available.
    /// - Throws: `ExifToolError` when validation or execution fails.
    nonisolated func extractAnalysisMetadata(
        from fileURL: URL,
        using runner: ExifToolRunner
    ) throws -> ExportPhotoMetadata? {
        let data = try runner.run(arguments: analysisArguments(for: fileURL))
        return try decodeAnalysisMetadata(from: data)
    }

    /// Builds the canonical analysis/export argument list for one file.
    /// - Parameter fileURL: The file URL to analyze.
    /// - Returns: ExifTool arguments using grouped `-G1` output.
    nonisolated func analysisArguments(for fileURL: URL) -> [String] {
        ExifToolTagWhitelist.analysisExportArguments + [fileURL.path]
    }

    /// Decodes the canonical analysis/export ExifTool JSON payload.
    /// - Parameter data: Raw JSON data produced by ExifTool.
    /// - Returns: The first unified metadata object, or `nil` when none exists.
    nonisolated func decodeAnalysisMetadata(from data: Data) throws -> ExportPhotoMetadata? {
        let metadata = try JSONDecoder().decode([ExportPhotoMetadata].self, from: data)
        return metadata.first
    }

    /// Creates the classic process-per-file runner.
    /// - Returns: A runner that launches ExifTool once for every request.
    /// - Throws: `ExifToolError` when bundled ExifTool cannot be resolved.
    nonisolated func makeProcessPerFileRunner() throws -> ProcessPerFileExifToolRunner {
        try ProcessPerFileExifToolRunner(runtime: runtime())
    }

    /// Creates a persistent `-stay_open` runner.
    /// - Returns: A runner backed by one long-lived ExifTool process.
    /// - Throws: `ExifToolError` or `PersistentExifToolRunnerError` when startup fails.
    nonisolated func makePersistentRunner() throws -> PersistentExifToolRunner {
        try PersistentExifToolRunner(runtime: runtime())
    }

    /// Returns the bundled ExifTool script path after checking that it exists in the app bundle.
    /// - Returns: The bundled ExifTool script path.
    /// - Throws: `ExifToolError` when the resource is missing.
    nonisolated func validatedExecutablePath() throws -> String {
        try bundledExifToolURL().path
    }

    /// Resolves the bundled ExifTool runtime used by process runners.
    /// - Returns: Runtime configuration for ExifTool process execution.
    /// - Throws: `ExifToolError` when ExifTool, its library, or Perl cannot be found.
    nonisolated private func runtime() throws -> ExifToolRuntime {
        guard FileManager.default.fileExists(atPath: perlPath) else {
            throw ExifToolError.perlNotFound(path: perlPath)
        }

        let exiftoolURL = bundledExifToolURLFromKnownLocations()

        guard let exiftoolURL else {
            throw ExifToolError.bundledExecutableNotFound(resourceName: executableResourceName)
        }

        let exiftoolDirectoryURL = exiftoolURL.deletingLastPathComponent()
        let exiftoolLibraryURL = exiftoolDirectoryURL.appendingPathComponent("lib", isDirectory: true)

        guard FileManager.default.fileExists(atPath: exiftoolLibraryURL.path) else {
            throw ExifToolError.bundledLibraryNotFound(path: exiftoolLibraryURL.path)
        }

        return ExifToolRuntime(
            perlURL: URL(fileURLWithPath: perlPath),
            exiftoolURL: exiftoolURL,
            workingDirectoryURL: exiftoolDirectoryURL,
            environment: processEnvironment(perlLibraryURL: exiftoolLibraryURL)
        )
    }

    /// Resolves the bundled ExifTool script URL and validates the Perl interpreter path.
    /// - Returns: The URL for the bundled ExifTool script.
    /// - Throws: `ExifToolError` when ExifTool or Perl cannot be found.
    nonisolated private func bundledExifToolURL() throws -> URL {
        try runtime().exiftoolURL
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
