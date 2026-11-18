import Contacts
import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localizedFormat(_ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments)
    }
}

struct ImportVCardView: View {
    @State private var viewModel: ImportVCardViewModel

    @MainActor
    init(viewModel: ImportVCardViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? ImportVCardViewModel())
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 18) {
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            GlassActionTile(
                                title: NSLocalizedString("China Yellow Pages", comment: ""),
                                subtitle: "公共服务黄页",
                                systemImage: "phone.circle.fill",
                                tint: .orange
                            ) {
                                HapticManager.medium()
                                Task { await viewModel.importChinaYellowPages() }
                            }

                            GlassActionTile(
                                title: NSLocalizedString("From File", comment: ""),
                                subtitle: "本地 .vcf 文件",
                                systemImage: "doc.circle.fill",
                                tint: .purple
                            ) {
                                HapticManager.medium()
                                viewModel.presentFilePicker()
                            }
                        }
                    }

                    GlassSectionCard(cornerRadius: 22, padding: 14, tint: .cyan) {
                        GlassRowButton(
                            title: NSLocalizedString("From URL", comment: ""),
                            subtitle: "从在线 URL 下载导入 vCard",
                            systemImage: "link.circle.fill",
                            tint: .cyan
                        ) {
                            HapticManager.medium()
                            viewModel.presentURLInput()
                        }
                    }

                    if !viewModel.importedContacts.isEmpty {
                        ImportResultsSection(contacts: viewModel.importedContacts)
                    }
                }
                .padding(16)
            }
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle(NSLocalizedString("Import vCards", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    viewModel.presentDeleteConfirmation()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $viewModel.isFilePickerPresented) {
            DocumentPicker { url in
                Task { await viewModel.importVCardFile(from: url) }
            }
        }
        .alert("Import Result".localized, isPresented: $viewModel.showAlert) {
            Button("OK".localized, role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .confirmationDialog(
            "Confirm Deletion".localized,
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete".localized, role: .destructive) {
                Task { await viewModel.deleteEmptyNameContacts() }
            }
            Button("Cancel".localized, role: .cancel) {}
        } message: {
            Text("Delete Confirmation Message".localized)
        }
        .alert(
            NSLocalizedString("Import from URL", comment: ""),
            isPresented: $viewModel.showURLInputAlert
        ) {
            TextField(NSLocalizedString("Enter vCards URL", comment: ""), text: $viewModel.urlString)
            Button(NSLocalizedString("Import", comment: "")) {
                Task { await viewModel.importFromEnteredURL() }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        }
    }
}

private struct ImportResultsSection: View {
    let contacts: [CNContact]

    var body: some View {
        GlassSectionCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Imported Contacts".localized)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Text(
                            String(
                                format: NSLocalizedString("Successfully imported %d contacts", comment: ""),
                                contacts.count
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(contacts.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.14), in: Capsule())
                }

                LazyVStack(spacing: 10) {
                    ForEach(contacts, id: \.stableIdentifier) { contact in
                        ImportedVCardContactRow(contact: contact)
                    }
                }
            }
        }
    }
}

private struct ImportedVCardContactRow: View {
    let contact: CNContact
    @State private var isExpanded = false

    private var titleText: String {
        if !contact.organizationName.isEmpty {
            return contact.organizationName
        }
        let fullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? NSLocalizedString("Unknown Contact", comment: "") : fullName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    AvatarThumbnailView(
                        source: .contact(contact, fallbackText: titleText),
                        size: 44,
                        tint: .blue
                    )
                    Text(titleText)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                        Label(phone.value.stringValue, systemImage: "phone.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(contact.urlAddresses, id: \.identifier) { url in
                        Label(url.value as String, systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 56)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let completion: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.vCard, UTType.data, UTType.text], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .formSheet
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (URL) -> Void

        init(completion: @escaping (URL) -> Void) {
            self.completion = completion
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            completion(url)
        }
    }
}
