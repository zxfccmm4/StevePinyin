import SwiftUI

struct ImportAvatarSelectionSectionState: Equatable {
    let importMode: AvatarImportMode
    let selectedPackage: AvatarPackage?
    let selectedUniformIcon: Icon?
    let urlString: String
    let contactsCount: Int
    let contactsNeedingSelectionCount: Int
    let manualSelectionsCount: Int
    let isMatching: Bool
}

struct ImportAvatarSelectionSection: View, Equatable {
    let state: ImportAvatarSelectionSectionState
    @Binding var downloadURLFieldVisible: Bool
    @Binding var showManualSelectionSheet: Bool
    let setURLString: (String) -> Void
    let showPackageSelector: () -> Void
    let selectUniformIcon: (Icon) -> Void
    let startMatching: () -> Void
    let downloadPackageAction: () async -> Void

    private var availableIconCount: Int {
        state.selectedPackage?.icons.count ?? 0
    }

    static func == (lhs: ImportAvatarSelectionSection, rhs: ImportAvatarSelectionSection) -> Bool {
        lhs.state == rhs.state &&
        lhs.downloadURLFieldVisible == rhs.downloadURLFieldVisible &&
        lhs.showManualSelectionSheet == rhs.showManualSelectionSheet
    }

    var body: some View {
        VStack(spacing: 18) {
            header

            if downloadURLFieldVisible {
                downloadComposerPanel
            } else {
                Group {
                    switch state.importMode {
                    case .single:
                        uniformAvatarSelector
                    case .manual:
                        manualAvatarSelector
                    case .sequential:
                        sequentialAvatarPreview
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Selection Studio", comment: ""))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("Preview the active icon set, tune the assignment mode, and bring in new packs without leaving the flow.", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                    downloadURLFieldVisible.toggle()
                }
            } label: {
                Label(
                    downloadURLFieldVisible
                        ? NSLocalizedString("Close", comment: "")
                        : NSLocalizedString("Download New", comment: ""),
                    systemImage: downloadURLFieldVisible ? "xmark" : "arrow.down.circle"
                )
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .glassCapsule(interactive: true)
        }
    }

    private var downloadComposerPanel: some View {
        ImportSubpanel(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Quick Download", comment: ""))
                            .font(.headline.weight(.semibold))

                        Text(NSLocalizedString("Paste a package link and pull it straight into your active library.", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ImportStatusChip(
                        title: NSLocalizedString("Import", comment: ""),
                        value: NSLocalizedString("URL", comment: ""),
                        systemImage: "link.badge.plus",
                        tint: .orange
                    )
                }

                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)

                    TextField(
                        NSLocalizedString("Enter package URL", comment: ""),
                        text: Binding(
                            get: { state.urlString },
                            set: setURLString
                        )
                    )
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if state.urlString.isEmpty == false {
                        Button(action: { setURLString("") }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear, Color.orange.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .glassCard(cornerRadius: 20)

                HStack(spacing: 12) {
                    lightweightActionButton(
                        title: NSLocalizedString("Dismiss", comment: ""),
                        systemImage: "xmark",
                        tint: .secondary,
                        prominent: false
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.76)) {
                            downloadURLFieldVisible = false
                        }
                    }

                    lightweightActionButton(
                        title: NSLocalizedString("Download", comment: ""),
                        systemImage: "arrow.down.circle.fill",
                        tint: .orange,
                        prominent: true
                    ) {
                        downloadPackage()
                    }
                }
            }
        }
    }

    private var uniformAvatarSelector: some View {
        Group {
            if let package = state.selectedPackage, package.icons.isEmpty == false {
                ImportSubpanel(tint: .blue) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("single_avatar_title", comment: ""))
                                    .font(.headline.weight(.semibold))

                                Text(NSLocalizedString("Choose one icon to apply across every matched contact.", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let selectedUniformIcon = state.selectedUniformIcon {
                                ImportStatusChip(
                                    title: NSLocalizedString("Selected", comment: ""),
                                    value: selectedUniformIcon.name,
                                    systemImage: "checkmark.circle.fill",
                                    tint: .blue
                                )
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(package.icons, id: \.url) { icon in
                                    ImportAvatarSelectButton(
                                        icon: icon,
                                        isSelected: state.selectedUniformIcon?.url == icon.url,
                                        onSelect: {
                                            selectUniformIcon(Icon(name: icon.name, url: icon.url))
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                ImportEmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    message: NSLocalizedString("No icons available", comment: ""),
                    action: showPackageSelector,
                    actionLabel: NSLocalizedString("Select Package", comment: "")
                )
            }
        }
    }

    private var manualAvatarSelector: some View {
        Group {
            if let package = state.selectedPackage, package.icons.isEmpty == false {
                ImportSubpanel(tint: .orange) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("Manual Assignment", comment: ""))
                                    .font(.headline.weight(.semibold))

                                Text(NSLocalizedString("Open the picker and decide avatar-by-avatar for the contacts that still need artwork.", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            ImportStatusChip(
                                title: NSLocalizedString("Selection", comment: ""),
                                value: state.contactsNeedingSelectionCount == 0
                                    ? NSLocalizedString("Ready", comment: "")
                                    : "\(state.manualSelectionsCount)/\(state.contactsNeedingSelectionCount)",
                                systemImage: "hand.tap.fill",
                                tint: .orange
                            )
                        }

                        if state.contactsNeedingSelectionCount > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(NSLocalizedString("Selections", comment: ""))
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(state.manualSelectionsCount) / \(state.contactsNeedingSelectionCount)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(
                                    value: Double(state.manualSelectionsCount),
                                    total: Double(state.contactsNeedingSelectionCount)
                                )
                                .tint(.orange)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.12), Color.clear, Color.white.opacity(0.03)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .glassCard(cornerRadius: 20)
                        }

                        lightweightActionButton(
                            title: NSLocalizedString("Select Avatars for Contacts", comment: ""),
                            systemImage: "hand.point.up.fill",
                            tint: .orange,
                            prominent: true,
                            isDisabled: state.contactsCount == 0
                        ) {
                            startMatching()
                        }
                    }
                }
                .onChange(of: state.isMatching) { _, isMatching in
                    if !isMatching &&
                        state.importMode == .manual &&
                        state.contactsNeedingSelectionCount > 0 &&
                        state.manualSelectionsCount == 0 {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(200))
                            guard !Task.isCancelled else { return }
                            showManualSelectionSheet = true
                        }
                    }
                }
            } else {
                ImportEmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    message: NSLocalizedString("No icons available", comment: ""),
                    action: showPackageSelector,
                    actionLabel: NSLocalizedString("Select Package", comment: "")
                )
            }
        }
    }

    private var sequentialAvatarPreview: some View {
        Group {
            if let package = state.selectedPackage, package.icons.isEmpty == false {
                ImportSubpanel(tint: .teal) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("Sequential Flow", comment: ""))
                                    .font(.headline.weight(.semibold))

                                Text(NSLocalizedString("Icons cycle through the active pack in order, giving each matched contact a different look.", comment: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            ImportStatusChip(
                                title: NSLocalizedString("Cycle", comment: ""),
                                value: "\(min(package.icons.count, 5)) / \(package.icons.count)",
                                systemImage: "arrow.triangle.2.circlepath",
                                tint: .teal
                            )
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(package.icons.prefix(5).enumerated()), id: \.element.url) { index, icon in
                                    VStack(spacing: 8) {
                                        ImportAvatarImage(icon: icon, size: 42)
                                        Text("\(index + 1)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    if index < 4 {
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if package.icons.count > 5 {
                                    Text("...")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                ImportEmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    message: NSLocalizedString("No icons available", comment: ""),
                    action: showPackageSelector,
                    actionLabel: NSLocalizedString("Select Package", comment: "")
                )
            }
        }
    }

    @ViewBuilder
    private func lightweightActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        prominent: Bool,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(tint)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1.0)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            .tint(tint)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1.0)
        }
    }

    private var modeTint: Color {
        switch state.importMode {
        case .single:
            return .blue
        case .sequential:
            return .teal
        case .manual:
            return .orange
        }
    }

    private func downloadPackage() {
        Task {
            await downloadPackageAction()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                downloadURLFieldVisible = false
            }
        }
    }
}
