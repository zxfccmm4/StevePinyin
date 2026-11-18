import SwiftUI

struct CleanupSheet: View {
    let onAction: (CleanupAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 14) {
                    CleanupHeroCard()

                    CleanupRow(
                        title: CleanupSheetStrings.cleanPinyin,
                        description: CleanupSheetStrings.cleanPinyinDescription,
                        icon: "textformat.abc",
                        color: .blue
                    ) {
                        HapticManager.medium()
                        dismiss()
                        onAction(.removePinyinOnly)
                    }

                    CleanupRow(
                        title: CleanupSheetStrings.cleanT9Search,
                        description: CleanupSheetStrings.cleanT9SearchDescription,
                        icon: "keyboard.badge.ellipsis",
                        color: .green
                    ) {
                        HapticManager.medium()
                        dismiss()
                        onAction(.removeT9Only)
                    }

                    CleanupRow(
                        title: CleanupSheetStrings.cleanupNoPhoneContacts,
                        description: CleanupSheetStrings.cleanupNoPhoneContactsDescription,
                        icon: "phone.down",
                        color: .pink
                    ) {
                        HapticManager.warning()
                        dismiss()
                        onAction(.cleanupNoPhone)
                    }

                    CleanupRow(
                        title: CleanupSheetStrings.deleteVCardsGroup,
                        description: CleanupSheetStrings.deleteVCardsGroupDescription,
                        icon: "folder.badge.minus",
                        color: .orange
                    ) {
                        HapticManager.warning()
                        dismiss()
                        onAction(.deleteVCardGroup)
                    }

                    CleanupRow(
                        title: CleanupSheetStrings.removeAll,
                        description: CleanupSheetStrings.removeAllDescription,
                        icon: "trash",
                        color: .red
                    ) {
                        HapticManager.rigid()
                        dismiss()
                        onAction(.removeAll)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle(CleanupSheetStrings.cleanup)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum CleanupSheetStrings {
    static let cleanup = String(localized: "Cleanup")
    static let cleanPinyin = String(localized: "Clean Pinyin")
    static let cleanPinyinDescription = String(localized: "Remove phonetic pinyin from all contacts")
    static let cleanT9Search = String(localized: "Clean T9 Search")
    static let cleanT9SearchDescription = String(localized: "Remove T9 search nicknames from all contacts")
    static let cleanupNoPhoneContacts = String(localized: "Cleanup No-Phone Contacts")
    static let cleanupNoPhoneContactsDescription = String(localized: "Delete contacts without phone numbers")
    static let deleteVCardsGroup = String(localized: "Delete vCards Group")
    static let deleteVCardsGroupDescription = String(localized: "Delete StevePinyin vCards group and its contacts")
    static let removeAll = String(localized: "Remove All")
    static let removeAllDescription = String(localized: "Remove all pinyin and T9 search data")
    static let heroDescription = String(localized: "Choose what to remove or reset from your contact database.")
    static let safe = String(localized: "Safe")
    static let targeted = String(localized: "Targeted")
    static let reset = String(localized: "Reset")
}

private struct CleanupHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.95), .orange.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(CleanupSheetStrings.cleanup)
                        .font(.title3.weight(.bold))

                    Text(CleanupSheetStrings.heroDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                GlassInfoChip(title: CleanupSheetStrings.safe, systemImage: "checkmark.shield.fill", tint: .green)
                GlassInfoChip(title: CleanupSheetStrings.targeted, systemImage: "scope", tint: .blue)
                GlassInfoChip(title: CleanupSheetStrings.reset, systemImage: "arrow.counterclockwise", tint: .orange)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24, tint: .red)
    }
}

private struct CleanupRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.95), color.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(color == .red ? .red : .primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color.opacity(0.9))

                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: 6, height: 32)
                }
            }
            .padding(18)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 22, tint: color, interactive: true)
    }
}
