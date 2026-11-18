import SwiftUI

struct PerformanceDiagnosticsView: View {
    @State private var monitor = PerformanceMonitor.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassSectionCard(tint: .blue) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("MetricKit 与实时性能看板", systemImage: "gauge.with.dots.needle.67percent")
                            .font(.system(.headline, design: .rounded, weight: .bold))

                        HStack(spacing: 10) {
                            GlassMetricBadge(
                                title: "即时追踪",
                                value: "\(monitor.immediateEventCount)",
                                systemImage: "bolt.fill",
                                tint: .blue
                            )
                            GlassMetricBadge(
                                title: "Metric 报告",
                                value: "\(monitor.metricReportCount)",
                                systemImage: "chart.bar.fill",
                                tint: .green
                            )
                            GlassMetricBadge(
                                title: "诊断报告",
                                value: "\(monitor.diagnosticReportCount)",
                                systemImage: "stethoscope",
                                tint: .orange
                            )
                        }

                        Button {
                            monitor.recordSnapshot()
                        } label: {
                            Label("记录当前性能快照", systemImage: "camera.metering.matrix")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    }
                }

                GlassSectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近 Signpost 事件（最多保留 200 条）")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if monitor.events.isEmpty {
                            ContentUnavailableView(
                                "暂无性能记录",
                                systemImage: "waveform.path.ecg",
                                description: Text("执行添加拼音、T9 生成、查重或头像导入后将在此显示耗时与阈值达标情况。")
                            )
                        } else {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(monitor.events) { event in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(event.title)
                                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                            Spacer()
                                            Text(event.timestamp, style: .time)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Text(event.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if let within = event.metadata["within_threshold"] {
                                            Text(within == "true" ? "阈值达标" : "超出预期阈值")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(within == "true" ? .green : .orange)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle("性能诊断")
        .navigationBarTitleDisplayMode(.inline)
    }
}
