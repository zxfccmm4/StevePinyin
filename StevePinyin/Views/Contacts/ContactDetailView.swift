import Contacts
import SwiftUI
import UIKit

struct ContactDetailView: View {
    @Binding var contact: ContactResult
    @Binding var processedContacts: [ContactResult]
    @State private var isEditing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    private let updatePinyinUseCase = UpdateContactPinyinUseCase()

    private var isCompanyOnly: Bool {
        contact.name.isEmpty && !contact.company.isEmpty
    }

    private var activePinyin: String {
        isCompanyOnly ? contact.companyPinyin : contact.pinyin
    }

    func updatePinyin(_ newPinyin: String) {
        isEditing = false
        let trimmedPinyin = newPinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPinyin.isEmpty else { return }

        Task { @MainActor in
            do {
                let result = try await updatePinyinUseCase.execute(contact: contact, newPinyin: trimmedPinyin)
                contact.pinyin = result.pinyin
                contact.companyPinyin = result.companyPinyin

                if let index = processedContacts.firstIndex(where: { $0.id == contact.id }) {
                    processedContacts[index].pinyin = result.pinyin
                    processedContacts[index].companyPinyin = result.companyPinyin
                }

                alertMessage = NSLocalizedString("Successfully updated pinyin", comment: "")
                showAlert = true
            } catch {
                alertMessage = String(format: NSLocalizedString("Error updating pinyin: %@", comment: ""), error.localizedDescription)
                showAlert = true
            }
        }
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 20) {
                    AvatarThumbnailView(
                        source: .contact(contact.contact, fallbackText: isCompanyOnly ? contact.company : contact.name),
                        size: 104,
                        tint: .blue
                    )
                    .padding(.top, 12)

                    if !contact.name.isEmpty {
                        GlassSectionCard(cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(String(localized: "name_label"), systemImage: "person.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(contact.name)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                            }
                        }
                    }

                    if !contact.company.isEmpty {
                        GlassSectionCard(cornerRadius: 22) {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(String(localized: "company_label"), systemImage: "building.2.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(contact.company)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                            }
                        }
                    }

                    GlassSectionCard(cornerRadius: 22, tint: .blue) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(
                                    isCompanyOnly
                                        ? NSLocalizedString("Company Pinyin", comment: "")
                                        : NSLocalizedString("Pinyin", comment: ""),
                                    systemImage: "character.book.closed.fill"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    isEditing = true
                                } label: {
                                    Label(NSLocalizedString("Edit", comment: ""), systemImage: "pencil")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.glass)
                            }

                            Text(activePinyin.isEmpty ? NSLocalizedString("No pinyin", comment: "") : activePinyin)
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                                .foregroundStyle(activePinyin.isEmpty ? .secondary : .primary)

                            Text(NSLocalizedString("Used for contact sorting and searching", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !activePinyin.isEmpty {
                        Button {
                            UIPasteboard.general.string = activePinyin
                            HapticManager.success()
                        } label: {
                            Label(NSLocalizedString("Copy Pinyin", comment: ""), systemImage: "doc.on.doc.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    }
                }
                .padding(16)
            }
        }
        .background(AmbientGlassBackdrop())
        .navigationTitle(NSLocalizedString("Contact Details", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            if isCompanyOnly {
                EditCompanyPinyinView(contact: contact, pinyin: contact.companyPinyin, onSave: updatePinyin)
            } else {
                EditPersonPinyinSheet(contact: contact, pinyin: contact.pinyin, onSave: updatePinyin)
            }
        }
        .alert(NSLocalizedString("Result", comment: ""), isPresented: $showAlert) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

private struct EditPersonPinyinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var pinyin: String
    let contact: ContactResult
    let onSave: (String) -> Void

    init(contact: ContactResult, pinyin: String, onSave: @escaping (String) -> Void) {
        self.contact = contact
        _pinyin = State(initialValue: pinyin)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AvatarThumbnailView(
                            source: .contact(contact.contact, fallbackText: contact.name),
                            size: 56,
                            tint: .blue
                        )
                        Text(contact.name)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    .padding(.vertical, 4)
                }

                Section(NSLocalizedString("Edit Pinyin", comment: "")) {
                    TextField(NSLocalizedString("Enter pinyin here", comment: ""), text: $pinyin)
                        .focused($isFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        HapticManager.medium()
                        let updated = pinyin
                        dismiss()
                        onSave(updated)
                    } label: {
                        Label(NSLocalizedString("Save Changes", comment: ""), systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(NSLocalizedString("Edit Pinyin", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
