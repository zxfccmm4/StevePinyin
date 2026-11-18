import SwiftUI

struct ImportAvatarPackageSection: View {
    @Bindable var viewModel: ImportAvatarsViewModel

    private var selectedPackageCount: Int {
        if viewModel.selectedPackages.isEmpty == false {
            return viewModel.selectedPackages.count
        }

        return viewModel.currentPackage == nil ? 0 : 1
    }

    private var totalSelectedIconCount: Int {
        if viewModel.selectedPackages.isEmpty == false {
            return viewModel.selectedPackages.reduce(0) { $0 + $1.icons.count }
        }

        return viewModel.currentPackage?.icons.count ?? 0
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if viewModel.selectedPackages.isEmpty == false {
                selectedPackagesPanel
            } else if let package = viewModel.currentPackage {
                focusedPackagePanel(package)
            } else {
                ImportEmptyStateView(
                    icon: "photo.stack",
                    message: NSLocalizedString("No package selected", comment: ""),
                    action: { viewModel.showingPackageSelector = true },
                    actionLabel: NSLocalizedString("Select Package", comment: "")
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Package Library", comment: ""))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("Choose one or more avatar packs and keep the active set ready for matching.", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.showingPackageSelector = true
            } label: {
                Label(NSLocalizedString("Browse", comment: ""), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .glassCapsule(interactive: true)
        }
    }

    private var selectedPackagesPanel: some View {
        VStack(spacing: 14) {
            ForEach(viewModel.selectedPackages, id: \.id) { package in
                packageCard(package)
            }

            HStack {
                Spacer()
                Text(
                    String(
                        format: NSLocalizedString("Active set includes %d icons", comment: ""),
                        totalSelectedIconCount
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func focusedPackagePanel(_ package: AvatarPackage) -> some View {
        ImportSubpanel(tint: package.isDefault ? .blue : .cyan) {
            HStack(alignment: .top, spacing: 16) {
                ImportPackagePreviewIcons(package: package)

                VStack(alignment: .leading, spacing: 8) {
                    Text(package.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(package.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ImportStatusChip(
                            title: NSLocalizedString("Icons", comment: ""),
                            value: "\(package.icons.count)",
                            systemImage: "photo.on.rectangle.angled",
                            tint: .cyan
                        )

                        if package.isDefault {
                            ImportStatusChip(
                                title: NSLocalizedString("Source", comment: ""),
                                value: NSLocalizedString("System", comment: ""),
                                systemImage: "checkmark.seal.fill",
                                tint: .blue
                            )
                        }
                    }
                }
            }
        }
    }

    private func packageCard(_ package: AvatarPackage) -> some View {
        ImportSubpanel(tint: package.isDefault ? .blue : .cyan) {
            HStack(alignment: .top, spacing: 16) {
                ImportPackagePreviewIcons(package: package)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(package.name)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(package.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Button {
                            viewModel.togglePackageSelection(package)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .glassCapsule(interactive: true)
                    }

                    HStack(spacing: 10) {
                        ImportStatusChip(
                            title: NSLocalizedString("Icons", comment: ""),
                            value: "\(package.icons.count)",
                            systemImage: "photo.on.rectangle.angled",
                            tint: .cyan
                        )

                        if package.isDefault {
                            ImportStatusChip(
                                title: NSLocalizedString("Source", comment: ""),
                                value: NSLocalizedString("System", comment: ""),
                                systemImage: "checkmark.seal.fill",
                                tint: .blue
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct ImportPackagePreviewIcons: View {
    let package: AvatarPackage

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(package.icons.prefix(3).enumerated()), id: \.offset) { index, icon in
                ImportAvatarImage(icon: icon, size: 46)
                    .offset(x: CGFloat(index) * 10)
                    .zIndex(Double(3 - index))
            }

            if package.icons.count > 3 {
                Text("+\(package.icons.count - 3)")
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 34)
                    .offset(x: 30, y: 24)
                    .glassCapsule()
                    .zIndex(0)
            }
        }
        .frame(width: 92, height: 58, alignment: .leading)
    }
}
