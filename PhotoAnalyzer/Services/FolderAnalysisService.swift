//
//  FolderAnalysisService.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 15/06/2026.
//

import Foundation

/// File-based folder analysis output for UI/statistics and AI package export.
nonisolated struct FolderAnalysisResult {
	/// Lightweight photo models used by UI and statistics.
	let photos: [PhotoInfo]

	/// Rich ExifTool metadata used by AI package export.
	let exportMetadata: [ExportPhotoMetadata]

	/// Source image files successfully analyzed, in stable visual/export order.
	let fileURLs: [URL]
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
			let normalizedCacheLimit = MetadataCacheSizeLimit.normalizedRawValue(metadataCacheMaximumSizeMB)
			let metadataCacheMaximumByteCount = MetadataCacheSizeLimit(rawValue: normalizedCacheLimit)?.byteCount
				?? MetadataCacheSizeLimit.mb512.byteCount
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
				print("Could not initialize ExifTool runner: \(error.localizedDescription)")
				return FolderAnalysisResult(photos: [], exportMetadata: [], fileURLs: [])
			}

			do {
				persistentRunner = try exifToolService.makePersistentRunner()
				activeRunner = persistentRunner ?? processPerFileRunner
				isUsingPersistentRunner = true
				#if DEBUG
				print("ExifTool runner: stay_open")
				#endif
			} catch {
				activeRunner = processPerFileRunner
				#if DEBUG
				print("ExifTool runner: process-per-file")
				print("Persistent ExifTool runner unavailable; using process-per-file fallback: \(error.localizedDescription)")
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
						exifToolService: exifToolService,
						metadataCacheService: metadataCacheService,
						metadataCacheSourceKey: metadataCacheSourceKeyByFileURL[fileURL],
						metadataCacheMaximumByteCount: metadataCacheMaximumByteCount,
						photoInfoMapper: photoInfoMapper,
						metadataCacheHitCount: &metadataCacheHitCount,
						photos: &photos,
						exportMetadataRecords: &exportMetadataRecords,
						analyzedFileURLs: &analyzedFileURLs
					)
				} catch let error as PersistentExifToolRunnerError where isUsingPersistentRunner {
					#if DEBUG
					print("Persistent ExifTool runner failed; falling back to process-per-file for the rest of this batch: \(error.localizedDescription)")
					#endif
					persistentRunner?.close()
					persistentRunner = nil
					activeRunner = processPerFileRunner
					isUsingPersistentRunner = false

					do {
						try appendMetadata(
							for: fileURL,
							using: activeRunner,
							exifToolService: exifToolService,
							metadataCacheService: metadataCacheService,
							metadataCacheSourceKey: metadataCacheSourceKeyByFileURL[fileURL],
							metadataCacheMaximumByteCount: metadataCacheMaximumByteCount,
							photoInfoMapper: photoInfoMapper,
							metadataCacheHitCount: &metadataCacheHitCount,
							photos: &photos,
							exportMetadataRecords: &exportMetadataRecords,
							analyzedFileURLs: &analyzedFileURLs
						)
					} catch {
						print("Could not extract ExifTool metadata for \(fileURL.lastPathComponent): \(error.localizedDescription)")
					}
				} catch {
					print("Could not extract ExifTool metadata for \(fileURL.lastPathComponent): \(error.localizedDescription)")
				}

				progressHandler?(
					ProgressSnapshot(
						completedUnitCount: Int64(offset + 1),
						totalUnitCount: Int64(fileURLs.count),
						message: "Reading metadata..."
					)
				)
			}

			print("Folder analysis completed.")
			print("Photos analyzed: \(photos.count)")
			print("Metadata cache hits: \(metadataCacheHitCount)")
			return FolderAnalysisResult(
				photos: photos,
				exportMetadata: exportMetadataRecords,
				fileURLs: analyzedFileURLs
			)
		}
	}

	private nonisolated func appendMetadata(
		for fileURL: URL,
		using runner: ExifToolRunner,
		exifToolService: ExifToolService,
		metadataCacheService: MetadataCacheService,
		metadataCacheSourceKey: MetadataCacheSourceKey?,
		metadataCacheMaximumByteCount: Int64,
		photoInfoMapper: PhotoInfoMapper,
		metadataCacheHitCount: inout Int,
		photos: inout [PhotoInfo],
		exportMetadataRecords: inout [ExportPhotoMetadata],
		analyzedFileURLs: inout [URL]
	) throws {
		let metadataData: Data
		let isCacheHit: Bool

		if let cachedData = metadataCacheService.cachedMetadataData(
			for: fileURL,
			sourceKey: metadataCacheSourceKey,
			maximumSizeBytes: metadataCacheMaximumByteCount
		) {
			metadataData = cachedData
			isCacheHit = true
			metadataCacheHitCount += 1
		} else {
			metadataData = try exifToolService.extractAnalysisMetadataData(from: fileURL, using: runner)
			isCacheHit = false
		}

		guard let metadata = try exifToolService.decodeAnalysisMetadata(from: metadataData) else {
			print("No ExifTool metadata returned for \(fileURL.lastPathComponent)")
			return
		}

		if !isCacheHit {
			metadataCacheService.storeMetadataData(
				metadataData,
				for: fileURL,
				sourceKey: metadataCacheSourceKey,
				maximumSizeBytes: metadataCacheMaximumByteCount
			)
		}

		let photoInfo = photoInfoMapper.photoInfo(from: metadata, fallbackFileURL: fileURL)
		photos.append(photoInfo)
		exportMetadataRecords.append(metadata)
		analyzedFileURLs.append(fileURL)
	}
}
