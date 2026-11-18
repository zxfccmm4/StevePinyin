import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private let highlights = WhatsNewContent.highlights

    var body: some View {
        ScrollView(showsIndicators: false) {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 20) {
                    headerBar
                    releaseBanner
                    highlightsBoard
                    bottomAction
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(AmbientGlassBackdrop())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var versionText: String {
        Bundle.main.infoDictionary?[WhatsNewContent.bundleShortVersionKey] as? String ?? WhatsNewContent.releaseVersion
    }

    private var buildText: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(WhatsNewViewStrings.whatsNew)
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text(String(format: WhatsNewViewStrings.versionFormat, versionText))
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                HapticManager.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .glassCapsule(interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WhatsNewViewStrings.close)
        }
    }

    private var releaseBanner: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.95), .cyan.opacity(0.56)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)

                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(WhatsNewViewStrings.releaseEyebrow)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.blue)
                        .tracking(1.2)

                    Text(String(format: WhatsNewViewStrings.releaseTitleFormat, WhatsNewContent.releaseVersion))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(WhatsNewViewStrings.releaseSummary)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                metricCapsule(
                    title: WhatsNewContent.searchMetricTitle,
                    value: WhatsNewContent.searchMetricValue,
                    tint: .blue
                )
                metricCapsule(
                    title: WhatsNewContent.importMetricTitle,
                    value: WhatsNewContent.importMetricValue,
                    tint: .orange
                )
            }

            if let buildText {
                Text(String(format: WhatsNewViewStrings.buildFormat, buildText))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassCapsule()
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.16), .cyan.opacity(0.08), .white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .glassCard(cornerRadius: 30, tint: .blue)
    }

    private var highlightsBoard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(WhatsNewViewStrings.highlightsTitle)
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    Text(WhatsNewViewStrings.highlightsSubtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                    WhatsNewTrackRow(
                        highlight: highlight,
                        showsConnector: index < highlights.count - 1
                    )
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .glassCard(cornerRadius: 28)
    }

    private func metricCapsule(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .tracking(1)

            Text(value)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 18)
    }

    private var bottomAction: some View {
        Button {
            HapticManager.medium()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(WhatsNewViewStrings.continueLabel)
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .blue.opacity(0.22), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct WhatsNewHighlight: Identifiable {
    let id = UUID()
    let title: String
    let eyebrow: String
    let summary: String
    let symbol: String
    let accent: Color
    let detailItems: [String]
}

private enum WhatsNewContent {
    static let releaseVersion = "3.0"
    static let bundleShortVersionKey = "CFBundleShortVersionString"
    static let searchMetricTitle = WhatsNewViewStrings.searchMetric
    static let searchMetricValue = WhatsNewViewStrings.searchMetricValue
    static let importMetricTitle = WhatsNewViewStrings.importMetric
    static let importMetricValue = WhatsNewViewStrings.importMetricValue

    static let highlights: [WhatsNewHighlight] = [
        .init(
            title: WhatsNewViewStrings.releaseTitle,
            eyebrow: WhatsNewViewStrings.releaseEyebrowBoard,
            summary: WhatsNewViewStrings.releaseSummaryBoard,
            symbol: "sparkles.rectangle.stack.fill",
            accent: .blue,
            detailItems: [WhatsNewViewStrings.releaseDetailOne]
        ),
        .init(
            title: WhatsNewViewStrings.pinyinTitle,
            eyebrow: WhatsNewViewStrings.pinyinEyebrow,
            summary: WhatsNewViewStrings.pinyinSummary,
            symbol: "character.book.closed.fill",
            accent: .orange,
            detailItems: [WhatsNewViewStrings.pinyinDetailOne]
        ),
        .init(
            title: WhatsNewViewStrings.avatarImportTitle,
            eyebrow: WhatsNewViewStrings.avatarImportEyebrow,
            summary: WhatsNewViewStrings.avatarImportSummary,
            symbol: "square.and.arrow.down.fill",
            accent: .red,
            detailItems: [WhatsNewViewStrings.avatarImportDetailOne]
        ),
        .init(
            title: WhatsNewViewStrings.speedTitle,
            eyebrow: WhatsNewViewStrings.speedEyebrow,
            summary: WhatsNewViewStrings.speedSummary,
            symbol: "bolt.fill",
            accent: .yellow,
            detailItems: [WhatsNewViewStrings.speedDetailOne]
        ),
        .init(
            title: WhatsNewViewStrings.accuracyTitle,
            eyebrow: WhatsNewViewStrings.accuracyEyebrow,
            summary: WhatsNewViewStrings.accuracySummary,
            symbol: "checkmark.seal.fill",
            accent: .green,
            detailItems: [WhatsNewViewStrings.accuracyDetailOne]
        ),
        .init(
            title: WhatsNewViewStrings.moreFeaturesTitle,
            eyebrow: WhatsNewViewStrings.moreFeaturesEyebrow,
            summary: WhatsNewViewStrings.moreFeaturesSummary,
            symbol: "plus.circle.fill",
            accent: .purple,
            detailItems: [WhatsNewViewStrings.moreFeaturesDetailOne]
        ),
    ]
}

private struct WhatsNewTrackRow: View {
    let highlight: WhatsNewHighlight
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(highlight.accent.opacity(0.16))
                        .frame(width: 42, height: 42)

                    Image(systemName: highlight.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(highlight.accent)
                }

                if showsConnector {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [highlight.accent.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 88)
                        .padding(.top, 8)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(highlight.eyebrow)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(highlight.accent)
                        .tracking(1.1)

                    Text(highlight.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    Text(highlight.summary)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(highlight.detailItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(highlight.accent)
                                .padding(.top, 2)

                            Text(item)
                                .font(.system(.footnote, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 20)
            }
        }
    }
}

private enum WhatsNewViewStrings {
    static let whatsNew = String(localized: "What's New")
    static let versionFormat = String(localized: "Version %@")
    static let buildFormat = String(localized: "Build %@")
    static let close = String(localized: "Close")
    static let continueLabel = String(localized: "Continue")

    static let releaseEyebrow = String(localized: "Release Notes")
    static let releaseTitleFormat = String(localized: "StevePinyin %@")
    static let releaseSummary = String(localized: "StevePinyin 3.0 is here with a brand-new design and a brand-new experience.")

    static let searchMetric = String(localized: "Speed")
    static let searchMetricValue = String(localized: "2x faster")
    static let importMetric = String(localized: "Accuracy")
    static let importMetricValue = String(localized: "+50%")

    static let highlightsTitle = String(localized: "Update Board")
    static let highlightsSubtitle = String(localized: "Six major updates in StevePinyin 3.0.")

    static let releaseEyebrowBoard = String(localized: "3.0 Release")
    static let releaseTitle = String(localized: "Brand-New Design")
    static let releaseSummaryBoard = String(localized: "StevePinyin 3.0 goes live with a completely refreshed design language and overall experience.")
    static let releaseDetailOne = String(localized: "StevePinyin 3.0 上线，全新的设计，全新的体验")

    static let pinyinEyebrow = String(localized: "Pinyin")
    static let pinyinTitle = String(localized: "Pinyin Page Fully Rebuilt")
    static let pinyinSummary = String(localized: "The Pinyin page is now redesigned around direct-use cards for a faster workflow.")
    static let pinyinDetailOne = String(localized: "Pinyin 页面完全重构，卡片设计点击即用")

    static let avatarImportEyebrow = String(localized: "Avatar Import")
    static let avatarImportTitle = String(localized: "A New Import Flow")
    static let avatarImportSummary = String(localized: "The avatar import page now uses a more efficient and easier-to-follow process design.")
    static let avatarImportDetailOne = String(localized: "导入头像页面完全重构，全新流程化设计更高效更好用")

    static let speedEyebrow = String(localized: "Performance")
    static let speedTitle = String(localized: "2x Faster Import Speed")
    static let speedSummary = String(localized: "Import speed has been improved significantly across the flow.")
    static let speedDetailOne = String(localized: "导入速度提升 2 倍")

    static let accuracyEyebrow = String(localized: "Accuracy")
    static let accuracyTitle = String(localized: "50% Better Pinyin Accuracy")
    static let accuracySummary = String(localized: "Pinyin generation is now more reliable and produces better results.")
    static let accuracyDetailOne = String(localized: "Pinyin 添加正确率提升 50%")

    static let moreFeaturesEyebrow = String(localized: "More")
    static let moreFeaturesTitle = String(localized: "More New Features")
    static let moreFeaturesSummary = String(localized: "This release also expands what you can do across the app.")
    static let moreFeaturesDetailOne = String(localized: "新增更多功能")
}

#Preview {
    NavigationStack {
        WhatsNewView()
    }
}
