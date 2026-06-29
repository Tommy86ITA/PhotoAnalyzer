//
//  FolderAnalysisService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import Foundation
import OSLog

/// File-based folder analysis output for UI/statistics and AI package export.
nonisolated struct FolderAnalysisResult {
	/// Lightweight photo models used by UI and statistics.
	let photos: [PhotoInfo]

	/// Rich ExifTool metadata used by AI package export.
	let exportMetadata: [ExportPhotoMetadata]

	/// Source image files successfully analyzed, in stable visual/export order.
	let fileURLs: [URL]

	/// Number of metadata records served from the persistent metadata cache.
	let metadataCacheHitCount: Int

	init(
		photos: [PhotoInfo],
		exportMetadata: [ExportPhotoMetadata],
		fileURLs: [URL],
		metadataCacheHitCount: Int = 0
	) {
		self.photos = photos
		self.exportMetadata = exportMetadata
		self.fileURLs = fileURLs
		self.metadataCacheHitCount = metadataCacheHitCount
	}
}

/// A service responsible for analyzing image files directly from a folder on disk.
final class FolderAnalysisService {
	/// Creates a folder analysis service.
	nonisolated init() {}

	/// Builds `PhotoInfo` values for supported image files using ExifTool as the primary metadata source.
	/// - Parameters:
	///   - folderURL: The folder URL selected by the user.
	///   - includeSubfolders: Whether subfolders should be scanned recursively.
	/// - Returns: Photo information models created from ExifTool metadata.
	nonisolated func analyzeFolder(at folderURL: URL, includeSubfolders: Bool = false) async throws -> [PhotoInfo] {
		try await analyzeFolderWithExportMetadata(at: folderURL, includeSubfolders: includeSubfolders).photos
	}

	/// Builds `PhotoInfo` values and rich export metadata for supported image files.
	/// - Parameters:
	///   - folderURL: The folder URL selected by the user.
	///   - includeSubfolders: Whether subfolders should be scanned recursively.
	/// - Returns: Photo information models plus export metadata records.
	nonisolated func analyzeFolderWithExportMetadata(
		at folderURL: URL,
		includeSubfolders: Bool = false
	) async throws -> FolderAnalysisResult {
		let fileURLs = PerformanceLogger.measure("Scanning files") {
			ImageFileScanner().imageFileURLs(in: folderURL, includeSubfolders: includeSubfolders)
		}

		try Task.checkCancellation()
		return try await analyzeFilesWithExportMetadata(fileURLs)
	}

	/// Builds `PhotoInfo` values and rich export metadata for supported image files.
	/// - Parameter fileURLs: Supported image files to analyze in stable order.
	/// - Returns: Photo information models plus export metadata records.
	nonisolated func analyzeFilesWithExportMetadata(_ fileURLs: [URL]) async throws -> FolderAnalysisResult {
		try await analyzeFilesWithExportMetadata(
			fileURLs,
			metadataCacheSourceKeyByFileURL: [:],
			metadataCacheMaximumSizeMB: MetadataCacheSizeLimit.mb512.rawValue,
			progressHandler: nil
		)
	}

	/// Builds `PhotoInfo` values and rich export metadata for supported image files.
	/// - Parameters:
	///   - fileURLs: Supported image files to analyze in stable order.
	///   - progressHandler: Optional progress callback for processed metadata files.
	/// - Returns: Photo information models plus export metadata records.
	nonisolated func analyzeFilesWithExportMetadata(
		_ fileURLs: [URL],
		metadataCacheSourceKeyByFileURL: [URL: MetadataCacheSourceKey],
		metadataCacheMaximumSizeMB: Int,
		progressHandler: (@Sendable (ProgressSnapshot) -> Void)?
	) async throws -> FolderAnalysisResult {
		try PerformanceLogger.measure("Reading metadata / ExifTool analysis") {
			let exifToolService = ExifToolService()
			let metadataCacheService = MetadataCacheService()
			let metadataReader = CachedExifMetadataReader(
				exifToolService: exifToolService,
				metadataCacheService: metadataCacheService,
				maximumSizeMB: metadataCacheMaximumSizeMB
			)
			let photoInfoMapper = PhotoInfoMapper()
			let processPerFileRunner: ExifToolRunner
			var persistentRunner: PersistentExifToolRunner?
			var activeRunner: ExifToolRunner
			var isUsingPersistentRunner = false
			var metadataCacheHitCount = 0
			var photos: [PhotoInfo] = []
			var exportMetadataRecords: [ExportPhotoMetadata] = []
			var analyzedFileURLs: [URL] = []
			photos.reserveCapacity(fileURLs.count)
			exportMetadataRecords.reserveCapacity(fileURLs.count)
			analyzedFileURLs.reserveCapacity(fileURLs.count)

			do {
				processPerFileRunner = try exifToolService.makeProcessPerFileRunner()
			} catch {
				AppLogger.analysis.error("Could not initialize ExifTool runner: \(error.localizedDescription, privacy: .public)")
				return FolderAnalysisResult(photos: [], exportMetadata: [], fileURLs: [])
			}

			do {
				persistentRunner = try exifToolService.makePersistentRunner()
				activeRunner = persistentRunner ?? processPerFileRunner
				isUsingPersistentRunner = true
				#if DEBUG
				AppLogger.analysis.debug("ExifTool runner: stay_open")
				#endif
			} catch {
				activeRunner = processPerFileRunner
				#if DEBUG
				AppLogger.analysis.debug("ExifTool runner: process-per-file")
				AppLogger.analysis.warning("Persistent ExifTool runner unavailable; using process-per-file fallback: \(error.localizedDescription, privacy: .public)")
				#endif
			}

			defer {
				persistentRunner?.close()
			}

			for (offset, fileURL) in fileURLs.enumerated() {
				try Task.checkCancellation()

				do {
					try appendMetadata(
						for: fileURL,
						using: activeRunner,
						metadataReader: metadataReader,
						metadataCacheSourceKey: metadataCacheSourceKeyByFileURL[fileURL],
						photoInfoMapper: photoInfoMapper,
						metadataCacheHitCount: &metadataCacheHitCount,
						photos: &photos,
						exportMetadataRecords: &exportMetadataRecords,
						analyzedFileURLs: &analyzedFileURLs
					)
				} catch let error as PersistentExifToolRunnerError where isUsingPersistentRunner {
					#if DEBUG
					AppLogger.analysis.warning("Persistent ExifTool runner failed; falling back to process-per-file for the rest of this batch: \(error.localizedDescription, privacy: .public)")
					#endif
					persistentRunner?.close()
					persistentRunner = nil
					activeRunner = processPerFileRunner
					isUsingPersistentRunner = false

					do {
						try appendMetadata(
							for: fileURL,
							using: activeRunner,
							metadataReader: metadataReader,
							metadataCacheSourceKey: metadataCacheSourceKeyByFileURL[fileURL],
							photoInfoMapper: photoInfoMapper,
							metadataCacheHitCount: &metadataCacheHitCount,
							photos: &photos,
							exportMetadataRecords: &exportMetadataRecords,
							analyzedFileURLs: &analyzedFileURLs
						)
					} catch {
						AppLogger.analysis.warning("Could not extract ExifTool metadata for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
					}
				} catch {
					AppLogger.analysis.warning("Could not extract ExifTool metadata for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
				}

				progressHandler?(
					ProgressSnapshot(
						completedUnitCount: Int64(offset + 1),
						totalUnitCount: Int64(fileURLs.count),
						message: "Reading metadata..."
					)
				)
			}

			AppLogger.analysis.info("Folder analysis completed.")
			AppLogger.analysis.info("Photos analyzed: \(photos.count, privacy: .public)")
			AppLogger.analysis.info("Metadata cache hits: \(metadataCacheHitCount, privacy: .public)")
			return FolderAnalysisResult(
				photos: photos,
				exportMetadata: exportMetadataRecords,
				fileURLs: analyzedFileURLs,
				metadataCacheHitCount: metadataCacheHitCount
			)
		}
	}

	private nonisolated func appendMetadata(
		for fileURL: URL,
		using runner: ExifToolRunner,
		metadataReader: CachedExifMetadataReader,
		metadataCacheSourceKey: MetadataCacheSourceKey?,
		photoInfoMapper: PhotoInfoMapper,
		metadataCacheHitCount: inout Int,
		photos: inout [PhotoInfo],
		exportMetadataRecords: inout [ExportPhotoMetadata],
		analyzedFileURLs: inout [URL]
	) throws {
		guard let result = try metadataReader.readMetadata(
			for: fileURL,
			sourceKey: metadataCacheSourceKey,
			using: runner
		) else {
			AppLogger.analysis.warning("No ExifTool metadata returned for \(fileURL.lastPathComponent, privacy: .public)")
			return
		}

		if result.isCacheHit {
			metadataCacheHitCount += 1
		}

		let photoInfo = photoInfoMapper.photoInfo(from: result.metadata, fallbackFileURL: fileURL)
		photos.append(photoInfo)
		exportMetadataRecords.append(result.metadata)
		analyzedFileURLs.append(fileURL)
	}
}
