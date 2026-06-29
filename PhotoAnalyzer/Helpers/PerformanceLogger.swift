//
//  PerformanceLogger.swift
//  PhotoAnalyzer
//
//  Created by Thomas Amaranto on 17/06/2026.
//

import Foundation
import OSLog

/// Lightweight utility used to measure execution times of analysis phases.
/// Logs are emitted only in DEBUG builds.
enum PerformanceLogger
{
	/// Measures the execution time of a synchronous block.
	///
	/// - Parameters:
	///   - label: Human-readable operation name.
	///   - block: Code to execute.
	/// - Returns: The result produced by the block.
	@discardableResult
	nonisolated static func measure<T>(_ label: String, block: () throws -> T) rethrows -> T
	{
		let start = CFAbsoluteTimeGetCurrent()
		let result = try block()
		let elapsed = CFAbsoluteTimeGetCurrent() - start

		#if DEBUG
		let formattedElapsed = String(format: "%.2f", elapsed)
		AppLogger.performance.debug("\(label, privacy: .public): \(formattedElapsed, privacy: .public)s")
		#endif

		return result
	}

	/// Measures the execution time of an async block.
	///
	/// - Parameters:
	///   - label: Human-readable operation name.
	///   - block: Async code to execute.
	/// - Returns: The result produced by the block.
	@discardableResult
	nonisolated static func measure<T>(_ label: String, block: () async throws -> T) async rethrows -> T
	{
		let start = CFAbsoluteTimeGetCurrent()
		let result = try await block()
		let elapsed = CFAbsoluteTimeGetCurrent() - start

		#if DEBUG
		let formattedElapsed = String(format: "%.2f", elapsed)
		AppLogger.performance.debug("\(label, privacy: .public): \(formattedElapsed, privacy: .public)s")
		#endif

		return result
	}
}
