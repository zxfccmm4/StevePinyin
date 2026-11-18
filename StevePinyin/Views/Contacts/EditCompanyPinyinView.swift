import SwiftUI

struct EditCompanyPinyinView: View {
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
                            source: .contact(contact.contact, fallbackText: contact.company),
                            size: 56,
                            tint: .blue
                        )
                        Text(contact.company)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    .padding(.vertical, 4)
                }

                Section(NSLocalizedString("Edit Company Pinyin", comment: "")) {
                    TextField(NSLocalizedString("Enter company pinyin here", comment: ""), text: $pinyin)
                        .focused($isFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section {
                    Text(NSLocalizedString("Enter the company pinyin for better sorting and searching experience", comment: ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .navigationTitle(NSLocalizedString("Edit Company Pinyin", comment: ""))
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
