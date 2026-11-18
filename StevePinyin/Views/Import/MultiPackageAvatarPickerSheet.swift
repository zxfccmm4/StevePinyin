import Contacts
import SwiftUI

struct MultiPackageAvatarPickerSheet: View {
    let contact: CNContact
    let icons: [AvatarIcon]
    let recommendations: [AvatarRecommendation]
    let onSelect: (AvatarIcon) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 12)
    ]

    private var filteredIcons: [AvatarIcon] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return icons }
        return icons.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !recommendations.isEmpty && searchText.isEmpty {
                        recommendationsSection
                    }

                    GlassSectionCard(cornerRadius: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("Library", comment: ""))
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                Spacer()
                                Text("\(filteredIcons.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }

                            if filteredIcons.isEmpty {
                                ContentUnavailableView.search(text: searchText)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filteredIcons) { icon in
                                        Button {
                                            HapticManager.selection()
                                            onSelect(icon)
                                        } label: {
                                            VStack(spacing: 8) {
                                                AvatarThumbnailView(source: .icon(icon), size: 58)
                                                Text(icon.name)
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity)
                                            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(contact.manualSheetDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("Search avatars", comment: ""))
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Close", comment: "")) { dismiss() }
                }
            }
        }
    }

    private var recommendationsSection: some View {
        GlassSectionCard(cornerRadius: 24, tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Apple Intelligence 推荐候选", systemImage: "apple.intelligence")
                    .font(.system(.headline, design: .rounded, weight: .bold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendations) { item in
                            Button {
                                HapticManager.selection()
                                onSelect(item.icon)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        AvatarThumbnailView(source: .icon(item.icon), size: 48)
                                        Spacer()
                                        Text("\(item.score)")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.purple, in: Capsule())
                                    }

                                    Text(item.icon.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(item.reasons.first ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .frame(width: 136, alignment: .leading)
                                .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
