//
//  AboutView.swift
//  StevePinyin
//
//  Created by Steve Zhou on 10/31/24.
//

import AppIntents
import ConfettiSwiftUI
import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("avatarIntelligenceMode") private var intelligenceModeRawValue: String = AvatarIntelligenceMode.system.rawValue
    @State private var confettiCounter = 0
    @State private var isShowPrivacyPolicy = false
    @State private var isShowT9ProblemSolving = false
    @State private var isShowAvatarPackSubmission = false

    private let intelligenceService = AvatarIntelligenceService()

    private var intelligenceMode: Binding<AvatarIntelligenceMode> {
        Binding(
            get: { AvatarIntelligenceMode(rawValue: intelligenceModeRawValue) ?? .system },
            set: { intelligenceModeRawValue = $0.rawValue }
        )
    }

    private var appDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "StevePinyin"
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
        return String(format: String(localized: "Version %@"), version)
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 18) {
                    heroCard
                    intelligenceCard
                    shortcutsCard
                    quickActionsCard
                    connectCard
                    thanksCard
                    footerButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle(String(localized: "About"))
        .navigationBarTitleDisplayMode(.inline)
        .confettiCannon(
            counter: $confettiCounter,
            colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
            confettiSize: 12,
            radius: 500
        )
        .sheet(isPresented: $isShowPrivacyPolicy) {
            PrivacyPolicyView { isShowPrivacyPolicy = false }
        }
        .sheet(isPresented: $isShowT9ProblemSolving) {
            T9ProblemSolvingView()
        }
        .sheet(isPresented: $isShowAvatarPackSubmission) {
            AvatarSubmissionSheet()
        }
    }

    private var heroCard: some View {
        GlassSectionCard(cornerRadius: 26, tint: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Button {
                        confettiCounter += 1
                        HapticManager.medium()
                    } label: {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(appDisplayName)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text(versionText)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemFill), in: Capsule())
                        }

                        Text(String(localized: "Pinyin tools, contact cleanup, and avatar workflows designed for modern iPhone habits."))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    GlassMetricBadge(title: "iOS 27", value: "AI 驱动", systemImage: "apple.intelligence", tint: .purple)
                    GlassMetricBadge(title: "T9 增强", value: "多音字", systemImage: "keyboard.fill", tint: .green)
                    GlassMetricBadge(title: "界面材质", value: "液态玻璃", systemImage: "sparkles", tint: .blue)
                }
            }
        }
    }

    private var intelligenceCard: some View {
        GlassSectionCard(cornerRadius: 24, tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Apple Intelligence 引擎", systemImage: "apple.intelligence")
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Picker("推理模式", selection: intelligenceMode) {
                    ForEach(AvatarIntelligenceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(intelligenceService.availabilitySummary(mode: intelligenceMode.wrappedValue))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcutsCard: some View {
        GlassSectionCard(cornerRadius: 24, tint: .indigo) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Siri 与快捷指令", systemImage: "sparkles.rectangle.stack.fill")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                }

                Text("支持免打开 App 直接通过 Siri 执行“添加通讯录拼音”、“开启 T9 搜索”、“检查重复联系人”与头像匹配。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActionsCard: some View {
        GlassSectionCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Quick Actions"))
                    .font(.system(.headline, design: .rounded, weight: .bold))

                GlassRowButton(
                    title: String(localized: "T9 Help"),
                    subtitle: String(localized: "Troubleshoot number-keyboard searching and dialing."),
                    systemImage: "keyboard.fill",
                    tint: .green
                ) {
                    isShowT9ProblemSolving = true
                }

                Divider()

                NavigationLink {
                    PerformanceDiagnosticsView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("性能与诊断看板")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("查看 MetricKit 系统指标与各批处理任务的耗时详情")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Divider()

                GlassRowButton(
                    title: String(localized: "Avatar Pack Submission"),
                    subtitle: String(localized: "Share your own pack with the community."),
                    systemImage: "person.crop.circle.badge.plus",
                    tint: .pink
                ) {
                    isShowAvatarPackSubmission = true
                }

                Divider()

                GlassRowButton(
                    title: String(localized: "Privacy Policy"),
                    subtitle: String(localized: "Review how StevePinyin handles your data and permissions."),
                    systemImage: "lock.shield.fill",
                    tint: .blue
                ) {
                    isShowPrivacyPolicy = true
                }
            }
        }
    }

    private var connectCard: some View {
        GlassSectionCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Connect"))
                    .font(.system(.headline, design: .rounded, weight: .bold))

                GlassRowButton(
                    title: String(localized: "Follow on Twitter"),
                    subtitle: String(localized: "Product updates, experiments, and direct contact."),
                    systemImage: "at",
                    tint: .blue,
                    trailingSystemImage: "arrow.up.forward"
                ) {
                    if let url = URL(string: "https://twitter.com/st7evechou") {
                        openURL(url)
                    }
                }

                Divider()

                GlassRowButton(
                    title: String(localized: "Join Telegram Group"),
                    subtitle: String(localized: "Talk with other users and share suggestions."),
                    systemImage: "paperplane.fill",
                    tint: .cyan,
                    trailingSystemImage: "arrow.up.forward"
                ) {
                    if let url = URL(string: "https://t.me/st7evee") {
                        openURL(url)
                    }
                }

                Divider()

                GlassRowButton(
                    title: String(localized: "Feedback"),
                    subtitle: String(localized: "Send bug reports, ideas, or general feedback by email."),
                    systemImage: "envelope.fill",
                    tint: .orange,
                    trailingSystemImage: "arrow.up.forward"
                ) {
                    if let url = URL(string: "mailto:stevepinyin@hotmail.com?subject=Feedback%20for%20StevePinyin") {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var thanksCard: some View {
        GlassSectionCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Special Thanks"))
                    .font(.system(.headline, design: .rounded, weight: .bold))

                GlassRowButton(
                    title: "ConfettiSwiftUI",
                    subtitle: String(localized: "Add beautiful confetti effects"),
                    systemImage: "sparkles",
                    tint: .purple,
                    trailingSystemImage: "arrow.up.forward"
                ) {
                    if let url = URL(string: "https://github.com/simibac/ConfettiSwiftUI") {
                        openURL(url)
                    }
                }

                Divider()

                GlassRowButton(
                    title: "vCards CN",
                    subtitle: String(localized: "Import common Chinese contact avatars to enhance iOS calling and messaging experience"),
                    systemImage: "person.text.rectangle.fill",
                    tint: .indigo,
                    trailingSystemImage: "arrow.up.forward"
                ) {
                    if let url = URL(string: "https://github.com/metowolf/vCards") {
                        openURL(url)
                    }
                }
            }
        }
    }

    private var footerButton: some View {
        Button {
            confettiCounter += 1
            HapticManager.medium()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text(String(localized: "Made with love by Steve"))
                    .foregroundStyle(.secondary)
            }
            .font(.system(.footnote, design: .rounded, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
