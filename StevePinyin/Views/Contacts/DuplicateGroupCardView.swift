import SwiftUI

struct DuplicateResultsSummaryCard: View {
    @Bindable var duplicateManager: DuplicateContactManager

    var body: some View {
        GlassSectionCard(cornerRadius: 24, padding: 18, tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(duplicateManager.duplicateResult.duplicateGroups.count) \(NSLocalizedString("Duplicate Groups", comment: ""))")
                            .font(.system(.title3, design: .rounded, weight: .bold))

                        Text("\(duplicateManager.duplicateResult.totalDuplicates) \(NSLocalizedString("Total Duplicates", comment: ""))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    DuplicateSelectionMenu(
                        isAllSelected: duplicateManager.duplicateResult.isAllSelected,
                        isSomeSelected: duplicateManager.duplicateResult.isSomeSelected,
                        onToggleAll: {
                            HapticManager.selection()
                            duplicateManager.duplicateResult.toggleSelectAll()
                        },
                        onSelectMode: { mode in
                            HapticManager.selection()
                            duplicateManager.duplicateResult.selectAllWithMode(mode)
                        }
                    )
                }

                HStack(spacing: 10) {
                    GlassMetricBadge(
                        title: NSLocalizedString("Duplicate Groups", comment: ""),
                        value: "\(duplicateManager.duplicateResult.duplicateGroups.count)",
                        systemImage: "square.stack.3d.up.fill",
                        tint: .orange
                    )

                    GlassMetricBadge(
                        title: NSLocalizedString("Selected", comment: ""),
                        value: "\(duplicateManager.duplicateResult.selectedCount)",
                        systemImage: "checkmark.circle.fill",
                        tint: .red
                    )
                }
            }
        }
    }
}

struct DuplicateGroupCard: View {
    @Binding var group: DuplicateGroup

    var body: some View {
        GlassSectionCard(cornerRadius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: group.duplicateType.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.duplicateType.displayName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text(group.matchingValue)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    DuplicateSelectionMenu(
                        isAllSelected: group.isAllSelected,
                        isSomeSelected: group.isSomeSelected,
                        onToggleAll: {
                            HapticManager.selection()
                            group.toggleSelectAll()
                        },
                        onSelectMode: { mode in
                            HapticManager.selection()
                            group.selectWithMode(mode)
                        }
                    )
                }

                VStack(spacing: 8) {
                    ForEach(group.contacts) { contact in
                        DuplicateContactRow(
                            contact: contact,
                            isSelected: group.selectedContacts.contains(contact.id)
                        ) {
                            HapticManager.selection()
                            group.toggleContact(contact.id)
                        }
                    }
                }
                .swipeActionsContainer()
            }
        }
    }
}

struct DuplicateContactRow: View {
    let contact: ContactResult
    let isSelected: Bool
    let onToggle: () -> Void

    private var displayTitle: String {
        !contact.name.isEmpty ? contact.name : contact.company
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                AvatarThumbnailView(
                    source: .contact(contact.contact, fallbackText: displayTitle),
                    size: 40,
                    tint: .orange
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)

                    if !contact.name.isEmpty, !contact.company.isEmpty {
                        Text(contact.company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if !contact.pinyin.isEmpty {
                        Text(contact.pinyin)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.red.opacity(0.12) : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(isSelected ? "取消标记" : "标记删除", action: onToggle)
                .tint(isSelected ? .gray : .red)
        }
    }
}

struct DuplicateSelectionMenu: View {
    let isAllSelected: Bool
    let isSomeSelected: Bool
    let onToggleAll: () -> Void
    let onSelectMode: (SelectionMode) -> Void

    var body: some View {
        Menu {
            Button(action: onToggleAll) {
                Label(
                    isAllSelected
                        ? NSLocalizedString("Deselect All", comment: "")
                        : NSLocalizedString("Select All", comment: ""),
                    systemImage: isAllSelected ? "minus.circle" : "checkmark.circle.fill"
                )
            }

            Divider()

            Button {
                onSelectMode(.selectOthersToDelete)
            } label: {
                Label(NSLocalizedString("Keep First, Select Others", comment: ""), systemImage: "checkmark.circle")
            }

            Button {
                onSelectMode(.selectFirstToDelete)
            } label: {
                Label(NSLocalizedString("Select First to Delete", comment: ""), systemImage: "1.circle")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isAllSelected ? "checkmark.circle.fill" : (isSomeSelected ? "minus.circle.fill" : "circle"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isAllSelected || isSomeSelected ? .orange : .secondary)

                Text(
                    isAllSelected
                        ? NSLocalizedString("Deselect All", comment: "")
                        : NSLocalizedString("Select All", comment: "")
                )
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassCapsule(interactive: true)
        }
        .buttonStyle(.plain)
    }
}
