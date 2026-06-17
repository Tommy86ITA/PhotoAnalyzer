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
	nonisolated func analyzeFolder(at folderURL: URL, includeSubfolders: Bool = false) async -> [PhotoInfo] {
		await analyzeFolderWithExportMetadata(at: folderURL, includeSubfolders: includeSubfolders).photos
	}

	/// Builds `PhotoInfo` values and rich export metadata for supported image files.
	/// - Parameters:
	///   - folderURL: The folder URL selected by the user.
	///   - includeSubfolders: Whether subfolders should be scanned recursively.
	/// - Returns: Photo information models plus export metadata records.
	nonisolated func analyzeFolderWithExportMetadata(
		at folderURL: URL,
		includeSubfolders: Bool = false
	) async -> FolderAnalysisResult {
		let fileURLs = PerformanceLogger.measure("Scanning files") {
			ImageFileScanner().imageFileURLs(in: folderURL, includeSubfolders: includeSubfolders)
		}

		return await analyzeFilesWithExportMetadata(fileURLs)
	}

	/// Builds `PhotoInfo` values and rich export metadata for supported image files.
	/// - Parameter fileURLs: Supported image files to analyze in stable order.
	/// - Returns: Photo information models plus export metadata records.
	nonisolated func analyzeFilesWithExportMetadata(_ fileURLs: [URL]) async -> FolderAnalysisResult {
		PerformanceLogger.measure("Reading metadata / ExifTool analysis") {
			let exifToolService = ExifToolService()
			let photoInfoMapper = PhotoInfoMapper()
			let processPerFileRunner: ExifToolRunner
			var persistentRunner: PersistentExifToolRunner?
			var activeRunner: ExifToolRunner
			var isUsingPersistentRunner = false
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

			for fileURL in fileURLs {
				do {
					try appendMetadata(
						for: fileURL,
						using: activeRunner,
						exifToolService: exifToolService,
						photoInfoMapper: photoInfoMapper,
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
							photoInfoMapper: photoInfoMapper,
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
			}

			print("Folder analysis completed.")
			print("Photos analyzed: \(photos.count)")
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
		photoInfoMapper: PhotoInfoMapper,
		photos: inout [PhotoInfo],
		exportMetadataRecords: inout [ExportPhotoMetadata],
		analyzedFileURLs: inout [URL]
	) throws {
		guard let metadata = try exifToolService.extractAnalysisMetadata(from: fileURL, using: runner) else {
			print("No ExifTool metadata returned for \(fileURL.lastPathComponent)")
			return
		}

		let photoInfo = photoInfoMapper.photoInfo(from: metadata, fallbackFileURL: fileURL)
		photos.append(photoInfo)
		exportMetadataRecords.append(metadata)
		analyzedFileURLs.append(fileURL)
	}
}
