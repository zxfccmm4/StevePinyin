//
//  PerformanceMonitor.swift
//  StevePinyin
//
//  MetricKit 性能监控服务
//

import Foundation
import MetricKit
import Observation
import os

// MARK: - 性能事件
struct PerformanceEvent: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
    let timestamp: Date
    let metadata: [String: String]

    init(title: String, detail: String, metadata: [String: String] = [:]) {
        self.title = title
        self.detail = detail
        self.timestamp = Date()
        self.metadata = metadata
    }
}

struct PerformanceThreshold {
    let durationLimit: TimeInterval
    let unitCount: Int
    let unitLabel: String

    func limit(for count: Int) -> TimeInterval {
        guard unitCount > 0 else { return durationLimit }
        return durationLimit * max(Double(count), 1) / Double(unitCount)
    }
}

// MARK: - 性能监控服务
@Observable
@MainActor
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    nonisolated private static let syncLogger = Logger(subsystem: "com.stevezhou.StevePinyin", category: "Performance")
    nonisolated private static let syncSignpostLog = OSLog(subsystem: "com.stevezhou.StevePinyin", category: "Signpost")

    private let logger = Logger(subsystem: "com.stevezhou.StevePinyin", category: "Performance")
    private let signpostLog = OSLog(subsystem: "com.stevezhou.StevePinyin", category: "Signpost")
    private let metricManager = MetricManager()

    private var metricTask: Task<Void, Never>?
    private var diagnosticTask: Task<Void, Never>?

    var events: [PerformanceEvent] = []
    var metricReportCount = 0
    var diagnosticReportCount = 0
    var immediateEventCount = 0

    private init() {}

    // MARK: - 启动监控
    func startMonitoring() {
        guard metricTask == nil, diagnosticTask == nil else { return }

        record(title: "PerformanceMonitor", detail: "已订阅 MetricKit 系统报告与即时 signpost 事件")

        metricTask = Task { [weak self] in
            guard let self else { return }

            for await report in metricManager.metricReports {
                await MainActor.run {
                    self.metricReportCount += 1
                    self.record(
                        title: "Metric Report",
                        detail: "收到系统性能指标报告：\(type(of: report))",
                        metadata: ["report_count": "\(self.metricReportCount)"]
                    )
                }
            }
        }

        diagnosticTask = Task { [weak self] in
            guard let self else { return }

            for await report in metricManager.diagnosticReports {
                await MainActor.run {
                    self.diagnosticReportCount += 1
                    self.record(
                        title: "Diagnostic Report",
                        detail: "收到系统诊断报告：\(type(of: report))",
                        metadata: ["report_count": "\(self.diagnosticReportCount)"]
                    )
                }
            }
        }
    }

    // MARK: - 停止监控
    func stopMonitoring() {
        metricTask?.cancel()
        diagnosticTask?.cancel()
        metricTask = nil
        diagnosticTask = nil
    }

    // MARK: - 关键路径追踪
    func trackBatchImport<T>(
        contactCount: Int,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await trackOperation(
            signpostName: "BatchAvatarImport",
            successTitle: "批量头像导入完成",
            failureTitle: "批量头像导入失败",
            detail: "联系人 \(contactCount) 位",
            count: contactCount,
            threshold: PerformanceThreshold(durationLimit: 30, unitCount: 100, unitLabel: "100 contacts"),
            metadata: ["contact_count": "\(contactCount)"],
            operation: operation
        )
    }

    nonisolated static func trackAvatarMatching<T>(
        contactCount: Int,
        mode: AvatarImportMode,
        operation: () throws -> T
    ) rethrows -> T {
        try Self.trackSynchronousOperation(
            signpostName: "AvatarMatching",
            successTitle: "头像匹配完成",
            failureTitle: "头像匹配失败",
            detail: "\(mode.title)，联系人 \(contactCount) 位",
            count: contactCount,
            threshold: PerformanceThreshold(durationLimit: 5, unitCount: 100, unitLabel: "100 contacts"),
            metadata: [
                "contact_count": "\(contactCount)",
                "mode": mode.rawValue,
            ],
            operation: operation
        )
    }

    func trackAvatarMatching<T>(
        contactCount: Int,
        mode: AvatarImportMode,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await trackOperation(
            signpostName: "AvatarMatching",
            successTitle: "头像匹配完成",
            failureTitle: "头像匹配失败",
            detail: "\(mode.title)，联系人 \(contactCount) 位",
            count: contactCount,
            threshold: PerformanceThreshold(durationLimit: 5, unitCount: 100, unitLabel: "100 contacts"),
            metadata: [
                "contact_count": "\(contactCount)",
                "mode": mode.rawValue,
            ],
            operation: operation
        )
    }

    nonisolated static func trackSynchronousOperation<T>(
        signpostName: StaticString,
        successTitle: String,
        failureTitle: String,
        detail: String,
        count: Int,
        threshold: PerformanceThreshold?,
        metadata: [String: String] = [:],
        operation: () throws -> T
    ) rethrows -> T {
        let signpostID = OSSignpostID(log: syncSignpostLog)
        let start = Date()

        mxSignpost(.begin, log: syncSignpostLog, name: signpostName, signpostID: signpostID)

        do {
            let value = try operation()
            let duration = Date().timeIntervalSince(start)

            mxSignpost(.end, log: syncSignpostLog, name: signpostName, signpostID: signpostID)
            recordSynchronousEvent(
                title: successTitle,
                detail: measuredDetail(base: detail, duration: duration, count: count, threshold: threshold),
                metadata: measuredMetadata(metadata, duration: duration, threshold: threshold?.limit(for: count))
            )

            return value
        } catch {
            let duration = Date().timeIntervalSince(start)

            mxSignpost(.end, log: syncSignpostLog, name: signpostName, signpostID: signpostID)
            var failureMetadata = measuredMetadata(metadata, duration: duration, threshold: threshold?.limit(for: count))
            failureMetadata["error"] = error.localizedDescription
            recordSynchronousEvent(
                title: failureTitle,
                detail: "\(detail)，失败原因：\(error.localizedDescription)",
                metadata: failureMetadata
            )

            throw error
        }
    }

    func trackDuplicateDetection<T>(
        typeCount: Int,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await trackOperation(
            signpostName: "DuplicateDetection",
            successTitle: "重复联系人检测完成",
            failureTitle: "重复联系人检测失败",
            detail: "检测规则 \(typeCount) 个",
            count: max(typeCount, 1),
            threshold: PerformanceThreshold(durationLimit: 3, unitCount: 1, unitLabel: "detection run"),
            metadata: ["type_count": "\(typeCount)"],
            operation: operation
        )
    }

    func trackAvatarPackageLoading<T>(
        source: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await trackOperation(
            signpostName: "AvatarPackageLoading",
            successTitle: "头像包加载完成",
            failureTitle: "头像包加载失败",
            detail: source,
            count: 1,
            threshold: PerformanceThreshold(durationLimit: 1, unitCount: 1, unitLabel: "package load"),
            metadata: ["source": source],
            operation: operation
        )
    }

    func trackPinyinMaintenance<T>(
        actionName: String,
        format: String? = nil,
        operation: () async throws -> T
    ) async rethrows -> T {
        var metadata = ["action": actionName]
        if let format {
            metadata["format"] = format
        }
        return try await trackOperation(
            signpostName: "ContactsPinyinMaintenance",
            successTitle: "\(actionName)完成",
            failureTitle: "\(actionName)失败",
            detail: format.map { "格式 \($0)" } ?? actionName,
            count: 1,
            threshold: PerformanceThreshold(durationLimit: 10, unitCount: 1, unitLabel: "maintenance run"),
            metadata: metadata,
            operation: operation
        )
    }

    func trackVCardImport<T>(
        source: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await trackOperation(
            signpostName: "VCardImport",
            successTitle: "vCard 导入完成",
            failureTitle: "vCard 导入失败",
            detail: source,
            count: 1,
            threshold: PerformanceThreshold(durationLimit: 8, unitCount: 1, unitLabel: "vCard import"),
            metadata: ["source": source],
            operation: operation
        )
    }

    func trackOperation<T>(
        signpostName: StaticString,
        successTitle: String,
        failureTitle: String,
        detail: String,
        count: Int,
        threshold: PerformanceThreshold?,
        metadata: [String: String] = [:],
        operation: () async throws -> T
    ) async rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)
        let start = Date()

        mxSignpost(.begin, log: signpostLog, name: signpostName, signpostID: signpostID)

        do {
            let value = try await operation()
            let duration = Date().timeIntervalSince(start)

            mxSignpost(.end, log: signpostLog, name: signpostName, signpostID: signpostID)
            record(
                title: successTitle,
                detail: measuredDetail(base: detail, duration: duration, count: count, threshold: threshold),
                metadata: measuredMetadata(metadata, duration: duration, threshold: threshold?.limit(for: count))
            )

            return value
        } catch {
            let duration = Date().timeIntervalSince(start)

            mxSignpost(.end, log: signpostLog, name: signpostName, signpostID: signpostID)
            var failureMetadata = measuredMetadata(metadata, duration: duration, threshold: threshold?.limit(for: count))
            failureMetadata["error"] = error.localizedDescription
            record(
                title: failureTitle,
                detail: "\(detail)，失败原因：\(error.localizedDescription)",
                metadata: failureMetadata
            )

            throw error
        }
    }

    // MARK: - 记录事件
    func record(title: String, detail: String, metadata: [String: String] = [:]) {
        logger.info("\(title, privacy: .public): \(detail, privacy: .public)")

        let event = PerformanceEvent(title: title, detail: detail, metadata: metadata)
        events.insert(event, at: 0)

        if events.count > 200 {
            events = Array(events.prefix(200))
        }

        immediateEventCount += 1
    }

    // MARK: - 记录快照
    func recordSnapshot() {
        record(
            title: "性能快照",
            detail: "即时事件: \(events.count), Metric Reports: \(metricReportCount), Diagnostics: \(diagnosticReportCount)",
            metadata: [
                "event_count": "\(events.count)",
                "metric_report_count": "\(metricReportCount)",
                "diagnostic_report_count": "\(diagnosticReportCount)",
            ]
        )
    }

    #if DEBUG
    func resetForTesting() {
        stopMonitoring()
        events.removeAll()
        metricReportCount = 0
        diagnosticReportCount = 0
        immediateEventCount = 0
    }
    #endif

    private func measuredDetail(
        base: String,
        duration: TimeInterval,
        count: Int,
        threshold: PerformanceThreshold?
    ) -> String {
        guard let threshold else {
            return "\(base)，耗时 \(formattedDuration(duration))"
        }

        let limit = threshold.limit(for: count)
        let status = duration <= limit ? "达标" : "超过阈值"
        return "\(base)，耗时 \(formattedDuration(duration))，阈值 \(formattedDuration(limit)) / \(threshold.unitLabel)，\(status)"
    }

    private func measuredMetadata(
        _ metadata: [String: String],
        duration: TimeInterval,
        threshold: TimeInterval?
    ) -> [String: String] {
        Self.measuredMetadata(metadata, duration: duration, threshold: threshold)
    }

    nonisolated private static func recordSynchronousEvent(
        title: String,
        detail: String,
        metadata: [String: String]
    ) {
        syncLogger.info("\(title, privacy: .public): \(detail, privacy: .public)")

        Task { @MainActor in
            PerformanceMonitor.shared.record(
                title: title,
                detail: detail,
                metadata: metadata
            )
        }
    }

    nonisolated private static func measuredDetail(
        base: String,
        duration: TimeInterval,
        count: Int,
        threshold: PerformanceThreshold?
    ) -> String {
        guard let threshold else {
            return "\(base)，耗时 \(formattedDuration(duration))"
        }

        let limit = threshold.limit(for: count)
        let status = duration <= limit ? "达标" : "超过阈值"
        return "\(base)，耗时 \(formattedDuration(duration))，阈值 \(formattedDuration(limit)) / \(threshold.unitLabel)，\(status)"
    }

    nonisolated private static func measuredMetadata(
        _ metadata: [String: String],
        duration: TimeInterval,
        threshold: TimeInterval?
    ) -> [String: String] {
        var result = metadata
        result["duration_ms"] = "\(Int((duration * 1000).rounded()))"

        if let threshold {
            result["threshold_ms"] = "\(Int((threshold * 1000).rounded()))"
            result["within_threshold"] = duration <= threshold ? "true" : "false"
        }

        return result
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        Self.formattedDuration(duration)
    }

    nonisolated private static func formattedDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int((duration * 1000).rounded()))ms"
        }

        return String(format: "%.2fs", duration)
    }
}
