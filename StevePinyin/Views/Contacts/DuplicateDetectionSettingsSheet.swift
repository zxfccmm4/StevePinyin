import SwiftUI

struct DetectionSettingsSheet: View {
    @Bindable var duplicateManager: DuplicateContactManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        heroCard
                        rulesSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(DetectionSettingsStrings.detectionSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(DetectionSettingsStrings.cancel) {
                        dismiss()
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                startScanBar
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var heroCard: some View {
        GlassSectionCard(cornerRadius: 26, padding: 20, tint: .orange) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(DetectionSettingsStrings.detectionSettings)
                            .font(.system(.title3, design: .rounded, weight: .bold))

                        Text(DetectionSettingsStrings.tuneHowDuplicateMatchingWorks)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    GlassInfoChip(title: DetectionSettingsStrings.smartMatch, systemImage: "wand.and.stars", tint: .orange)
                    GlassInfoChip(title: DetectionSettingsStrings.flexibleRules, systemImage: "slider.horizontal.3", tint: .blue)
                    GlassInfoChip(title: DetectionSettingsStrings.contacts, systemImage: "person.2.fill", tint: .green)
                }
            }
        }
    }

    private var rulesSection: some View {
        GlassSectionCard(cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DetectionSettingsStrings.selectDetectionTypes)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(DetectionSettingsStrings.selectDetectionTypesSubtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(DuplicateType.allCases, id: \.self) { type in
                        DetectionTypeToggle(
                            type: type,
                            isSelected: duplicateManager.selectedDuplicateTypes.contains(type)
                        ) {
                            HapticManager.selection()
                            if duplicateManager.selectedDuplicateTypes.contains(type) {
                                duplicateManager.selectedDuplicateTypes.remove(type)
                            } else {
                                duplicateManager.selectedDuplicateTypes.insert(type)
                            }
                        }
                    }
                }
            }
        }
    }

    private var startScanBar: some View {
        VStack(spacing: 0) {
            Button {
                HapticManager.medium()
                dismiss()
                duplicateManager.detectDuplicates()
            } label: {
                Label(DetectionSettingsStrings.startDetection, systemImage: "magnifyingglass")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
            .disabled(duplicateManager.selectedDuplicateTypes.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct DetectionTypeToggle: View {
    let type: DuplicateType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: isSelected ? [.orange, .red] : [Color(.tertiarySystemFill), Color(.tertiarySystemFill)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(typeDescription)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? .orange : .secondary)
            }
            .padding(12)
            .background(
                isSelected ? Color.orange.opacity(0.1) : Color(.tertiarySystemFill).opacity(0.6),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var typeDescription: String {
        switch type {
        case .exactName:
            return DetectionSettingsStrings.findContactsWithIdenticalNames
        case .similarName:
            return DetectionSettingsStrings.findContactsWithSimilarNames
        case .samePhone:
            return DetectionSettingsStrings.findContactsWithSamePhoneNumbers
        case .sameEmail:
            return DetectionSettingsStrings.findContactsWithSameEmailAddresses
        case .samePinyin:
            return DetectionSettingsStrings.findContactsWithIdenticalPinyin
        }
    }
}

private enum DetectionSettingsStrings {
    static let detectionSettings = String(localized: "Detection Settings")
    static let cancel = String(localized: "Cancel")
    static let selectDetectionTypes = String(localized: "Select Detection Types")
    static let selectDetectionTypesSubtitle = String(
        localized: "Choose the matching rules that should be used when scanning your contacts."
    )
    static let startDetection = String(localized: "Start Detection")
    static let tuneHowDuplicateMatchingWorks = String(
        localized: "Tune how duplicate matching works before scanning your address book."
    )
    static let smartMatch = String(localized: "Smart Match")
    static let flexibleRules = String(localized: "Flexible Rules")
    static let contacts = String(localized: "Contacts")
    static let findContactsWithIdenticalNames = String(localized: "Find contacts with identical names")
    static let findContactsWithSimilarNames = String(localized: "Find contacts with similar names")
    static let findContactsWithSamePhoneNumbers = String(localized: "Find contacts with same phone numbers")
    static let findContactsWithSameEmailAddresses = String(localized: "Find contacts with same email addresses")
    static let findContactsWithIdenticalPinyin = String(localized: "Find contacts with identical pinyin")
}
