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
	/// - Parameter folderURL: The folder URL selected by the user.
	/// - Returns: Photo information models created from ExifTool metadata.
	nonisolated func analyzeFolder(at folderURL: URL) async -> [PhotoInfo] {
		await analyzeFolderWithExportMetadata(at: folderURL).photos
	}

	/// Builds `PhotoInfo` values and rich export metadata for supported image files.
	/// - Parameter folderURL: The folder URL selected by the user.
	/// - Returns: Photo information models plus export metadata records.
	nonisolated func analyzeFolderWithExportMetadata(at folderURL: URL) async -> FolderAnalysisResult {
		let fileURLs = PerformanceLogger.measure("Scanning files") {
			ImageFileScanner().imageFileURLs(in: folderURL)
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
			var photos: [PhotoInfo] = []
			var exportMetadataRecords: [ExportPhotoMetadata] = []
			var analyzedFileURLs: [URL] = []
			photos.reserveCapacity(fileURLs.count)
			exportMetadataRecords.reserveCapacity(fileURLs.count)
			analyzedFileURLs.reserveCapacity(fileURLs.count)

			for fileURL in fileURLs {
				do {
					guard let metadata = try exifToolService.extractAnalysisMetadata(from: fileURL) else {
						print("No ExifTool metadata returned for \(fileURL.lastPathComponent)")
						continue
					}

					let photoInfo = photoInfoMapper.photoInfo(from: metadata, fallbackFileURL: fileURL)
					photos.append(photoInfo)
					exportMetadataRecords.append(metadata)
					analyzedFileURLs.append(fileURL)
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
}
