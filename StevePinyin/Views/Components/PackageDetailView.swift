import AppIntents
import SwiftUI

struct PackageDetailView: View {
    let package: AvatarPackage
    @Binding var selectedIcons: [String: Icon]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredIcons: [AvatarIcon] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return package.icons }
        return package.icons.filter { $0.name.localizedStandardContains(query) }
    }

    private var formattedDate: String {
        package.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var allFilteredSelected: Bool {
        !filteredIcons.isEmpty && filteredIcons.allSatisfy { selectedIcons[$0.url] != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        headerCard
                        iconsGridCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .background(AmbientGlassBackdrop())
            .appEntityIdentifier(
                EntityIdentifier(for: AvatarPackageEntity.self, identifier: package.id)
            )
            .navigationTitle(package.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .automatic,
                prompt: NSLocalizedString("搜索图标...", comment: "")
            )
            .searchToolbarBehavior(.minimize)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "")) {
                        HapticManager.light()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private var headerCard: some View {
        GlassSectionCard(cornerRadius: 26, padding: 20, tint: .blue) {
            VStack(spacing: 16) {
                HStack(spacing: -14) {
                    ForEach(Array(package.icons.prefix(4).enumerated()), id: \.offset) { index, icon in
                        AvatarThumbnailView(source: .icon(icon), size: 54, tint: .blue)
                            .zIndex(Double(4 - index))
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Text(package.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)

                    if !package.description.isEmpty {
                        Text(package.description)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    GlassMetricBadge(
                        title: String(localized: "icon_count"),
                        value: "\(package.icons.count)",
                        systemImage: "photo.stack",
                        tint: .blue
                    )

                    GlassMetricBadge(
                        title: NSLocalizedString("Selected", comment: ""),
                        value: "\(selectedIcons.count)",
                        systemImage: "checkmark.circle",
                        tint: .green
                    )

                    GlassMetricBadge(
                        title: package.isDefault
                            ? NSLocalizedString("Type", comment: "")
                            : NSLocalizedString("Added On", comment: ""),
                        value: package.isDefault ? String(localized: "system_built_in") : formattedDate,
                        systemImage: package.isDefault ? "star.fill" : "calendar",
                        tint: package.isDefault ? .orange : .purple
                    )
                }
            }
        }
    }

    private var iconsGridCard: some View {
        GlassSectionCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Text(NSLocalizedString("图标库", comment: ""))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Text("(\(filteredIcons.count))")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !filteredIcons.isEmpty {
                        Button(action: toggleAllSelection) {
                            Label(
                                allFilteredSelected
                                    ? NSLocalizedString("Deselect All", comment: "")
                                    : NSLocalizedString("Select All", comment: ""),
                                systemImage: allFilteredSelected ? "checkmark.circle.fill" : "circle.grid.2x2"
                            )
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                    }
                }

                if filteredIcons.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(minHeight: 160)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 84), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(filteredIcons, id: \.url) { icon in
                            PackageIconCell(
                                icon: icon,
                                isSelected: selectedIcons[icon.url] != nil
                            ) {
                                toggleIconSelection(icon)
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggleIconSelection(_ icon: AvatarIcon) {
        HapticManager.light()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            if selectedIcons[icon.url] != nil {
                selectedIcons.removeValue(forKey: icon.url)
            } else {
                selectedIcons[icon.url] = Icon(name: icon.name, url: icon.url)
            }
        }
    }

    private func toggleAllSelection() {
        HapticManager.medium()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            if allFilteredSelected {
                for icon in filteredIcons {
                    selectedIcons.removeValue(forKey: icon.url)
                }
            } else {
                for icon in filteredIcons {
                    selectedIcons[icon.url] = Icon(name: icon.name, url: icon.url)
                }
            }
        }
    }
}

struct PackageIconCell: View {
    let icon: AvatarIcon
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    AvatarThumbnailView(
                        source: .icon(icon),
                        size: 46,
                        cornerRadius: 12,
                        tint: isSelected ? .blue : .cyan
                    )
                    .frame(maxWidth: .infinity, minHeight: 68)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .blue)
                            .padding(6)
                    }
                }
                .glassCard(cornerRadius: 16, tint: isSelected ? .blue : nil, interactive: true)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.blue, lineWidth: 1.5)
                    }
                }

                Text(icon.name)
                    .font(.system(.caption2, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isSelected ? .blue : .primary)
            }
        }
        .buttonStyle(.plain)
    }
}
