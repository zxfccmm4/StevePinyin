import Foundation
import Testing
@testable import StevePinyin

@MainActor
@Suite(.serialized)
struct PerformanceMonitorTests {
    @Test("异步头像包加载会记录性能事件")
    func asyncPackageLoadingRecordsEvent() async throws {
        PerformanceMonitor.shared.resetForTesting()

        let value = await PerformanceMonitor.shared.trackAvatarPackageLoading(source: "unit-test-package") {
            42
        }

        #expect(value == 42)

        let event = try #require(PerformanceMonitor.shared.events.first)
        #expect(event.title == "头像包加载完成")
        #expect(event.detail.contains("unit-test-package"))
        #expect(event.metadata["source"] == "unit-test-package")
        #expect(event.metadata["duration_ms"] != nil)
        #expect(event.metadata["threshold_ms"] == "1000")
        #expect(event.metadata["within_threshold"] == "true")
    }

    @Test("同步头像匹配会回写统一性能事件")
    func synchronousAvatarMatchingRecordsEvent() async throws {
        PerformanceMonitor.shared.resetForTesting()

        let value = PerformanceMonitor.trackAvatarMatching(contactCount: 3, mode: .sequential) {
            "matched"
        }

        #expect(value == "matched")
        await waitForPerformanceEvent(title: "头像匹配完成")

        let event = try #require(PerformanceMonitor.shared.events.first)
        #expect(event.title == "头像匹配完成")
        #expect(event.metadata["contact_count"] == "3")
        #expect(event.metadata["mode"] == AvatarImportMode.sequential.rawValue)
        #expect(event.metadata["duration_ms"] != nil)
        #expect(event.metadata["threshold_ms"] == "150")
        #expect(event.metadata["within_threshold"] == "true")
    }

    @Test("性能事件最多保留最近 200 条")
    func recordsKeepLatestTwoHundredEvents() {
        PerformanceMonitor.shared.resetForTesting()

        for index in 0..<205 {
            PerformanceMonitor.shared.record(
                title: "事件 \(index)",
                detail: "detail \(index)"
            )
        }

        #expect(PerformanceMonitor.shared.events.count == 200)
        #expect(PerformanceMonitor.shared.events.first?.title == "事件 204")
        #expect(PerformanceMonitor.shared.events.last?.title == "事件 5")
        #expect(PerformanceMonitor.shared.immediateEventCount == 205)
    }

    private func waitForPerformanceEvent(title: String) async {
        for _ in 0..<10 {
            if PerformanceMonitor.shared.events.contains(where: { $0.title == title }) {
                return
            }

            await Task.yield()
        }
    }
}
