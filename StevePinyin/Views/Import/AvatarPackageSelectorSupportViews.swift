import SwiftUI

struct AvatarPackageGridConstants {
    static let spacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 20
    static let iconPreviewCount = 4
}

struct GridPackageCard: View, Equatable {
    let package: AvatarPackage
    var isNewlyImported: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void

    static func == (lhs: GridPackageCard, rhs: GridPackageCard) -> Bool {
        lhs.package == rhs.package &&
            lhs.isNewlyImported == rhs.isNewlyImported
    }

    var body: some View {
        PackageGridCardContent(
            package: package,
            isSelected: false,
            showsSelectionBadge: false,
            isNewlyImported: isNewlyImported,
            onPrimaryTap: onSelect,
            onDelete: onDelete
        )
    }
}

struct GridMultiSelectCard: View, Equatable {
    let package: AvatarPackage
    let isSelected: Bool
    var isNewlyImported: Bool = false
    let onToggle: () -> Void
    let onDelete: () -> Void

    static func == (lhs: GridMultiSelectCard, rhs: GridMultiSelectCard) -> Bool {
        lhs.package == rhs.package &&
            lhs.isSelected == rhs.isSelected &&
            lhs.isNewlyImported == rhs.isNewlyImported
    }

    var body: some View {
        PackageGridCardContent(
            package: package,
            isSelected: isSelected,
            showsSelectionBadge: true,
            isNewlyImported: isNewlyImported,
            onPrimaryTap: onToggle,
            onDelete: onDelete
        )
    }
}

private struct PackageGridCardContent: View {
    let package: AvatarPackage
    let isSelected: Bool
    let showsSelectionBadge: Bool
    let isNewlyImported: Bool
    let onPrimaryTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDetail = false
    @State private var showingDeleteAlert = false

    private var cardTint: Color? {
        if isNewlyImported { return .green }
        if isSelected { return .blue }
        return package.isDefault ? .cyan : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                iconPreviewGrid

                if showsSelectionBadge {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            isSelected ? .white : .secondary,
                            isSelected ? .blue : .clear
                        )
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(package.name)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if package.isDefault {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                Text(package.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .topLeading)
            }

            HStack {
                Label("\(package.icons.count)", systemImage: "photo.stack")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    HapticManager.light()
                    showingDetail = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassCard(
            cornerRadius: AvatarPackageGridConstants.cardCornerRadius,
            tint: cardTint,
            interactive: true
        )
        .overlay {
            if isSelected || isNewlyImported {
                RoundedRectangle(cornerRadius: AvatarPackageGridConstants.cardCornerRadius, style: .continuous)
                    .strokeBorder(isNewlyImported ? Color.green : Color.blue, lineWidth: 2)
            }
        }
        .contentShape(.rect(cornerRadius: AvatarPackageGridConstants.cardCornerRadius))
        .onTapGesture {
            onPrimaryTap()
        }
        .contextMenu {
            Button {
                showingDetail = true
            } label: {
                Label(NSLocalizedString("Details", comment: ""), systemImage: "info.circle")
            }

            if !package.isDefault {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            PackageDetailView(
                package: package,
                selectedIcons: .constant([:])
            )
        }
        .alert(NSLocalizedString("Confirm Delete", comment: ""), isPresented: $showingDeleteAlert) {
            Button(NSLocalizedString("Delete", comment: ""), role: .destructive) {
                HapticManager.warning()
                onDelete()
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(
                String(
                    format: NSLocalizedString(
                        "Are you sure you want to delete the package \"%@\"? This action cannot be undone.",
                        comment: ""
                    ),
                    package.name
                )
            )
        }
    }

    private var iconPreviewGrid: some View {
        let previewIcons = Array(package.icons.prefix(AvatarPackageGridConstants.iconPreviewCount))
        let remainingCount = package.icons.count - AvatarPackageGridConstants.iconPreviewCount
        let emptySlots = max(0, AvatarPackageGridConstants.iconPreviewCount - previewIcons.count)

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
            spacing: 6
        ) {
            ForEach(previewIcons.indices, id: \.self) { index in
                GridIconPreview(icon: previewIcons[index])
            }

            ForEach(0 ..< emptySlots, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .glassCapsule()
                    .padding(4)
            }
        }
    }
}

struct GridIconPreview: View {
    let icon: Icon

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, 32)
            AvatarThumbnailView(
                source: .icon(icon),
                size: side,
                cornerRadius: 10,
                tint: .blue
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

enum SortOption: String, CaseIterable {
    case newest = "newest"
    case oldest = "oldest"
    case name = "name"
    case iconCount = "iconCount"

    var title: String {
        switch self {
        case .newest: return NSLocalizedString("Newest", comment: "")
        case .oldest: return NSLocalizedString("Oldest", comment: "")
        case .name: return NSLocalizedString("Name", comment: "")
        case .iconCount: return NSLocalizedString("Icon Count", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .newest: return "clock.arrow.circlepath"
        case .oldest: return "clock"
        case .name: return "textformat.abc"
        case .iconCount: return "number.circle"
        }
    }
}

enum PackageCategory: String, CaseIterable {
    case all = "all"
    case system = "system"
    case custom = "custom"

    var title: String {
        switch self {
        case .all: return NSLocalizedString("All", comment: "")
        case .system: return NSLocalizedString("System", comment: "")
        case .custom: return NSLocalizedString("Custom", comment: "")
        }
    }
}
