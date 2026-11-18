import SwiftUI

struct AvatarSubmissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var themeName = ""
    @State private var urlLink = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var didSucceed = false

    private var canSubmit: Bool {
        themeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            urlLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 46))
                            .foregroundStyle(.purple)

                        Text(NSLocalizedString("Submit Your Avatar Pack", comment: ""))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text(NSLocalizedString("Share your creative avatar designs with the community", comment: ""))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section(NSLocalizedString("Avatar Pack Submission", comment: "")) {
                    TextField(NSLocalizedString("Enter theme name", comment: ""), text: $themeName)
                    TextField(NSLocalizedString("Enter URL link", comment: ""), text: $urlLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section(NSLocalizedString("Submission Guidelines", comment: "")) {
                    Label(NSLocalizedString("Original creative work only", comment: ""), systemImage: "checkmark.circle.fill")
                    Label(NSLocalizedString("High-quality avatar designs", comment: ""), systemImage: "checkmark.circle.fill")
                    Label(NSLocalizedString("Compatible with iOS contacts", comment: ""), systemImage: "checkmark.circle.fill")
                }

                Section {
                    Button(action: submit) {
                        Text(NSLocalizedString("Submit", comment: ""))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.purple)
                    .disabled(!canSubmit)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AmbientGlassBackdrop())
            .navigationTitle(NSLocalizedString("Avatar Pack Submission", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
            .alert(NSLocalizedString("Submission Status", comment: ""), isPresented: $showAlert) {
                Button(NSLocalizedString("OK", comment: "")) {
                    if didSucceed {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func submit() {
        HapticManager.medium()

        let subject = "Avatar Pack Submission"
        let body = "Theme Name: \(themeName)\nURL Link: \(urlLink)\n\nSubmitted via StevePinyin App"

        if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "mailto:stevepinyin@hotmail.com?subject=\(encodedSubject)&body=\(encodedBody)")
        {
            openURL(url) { success in
                didSucceed = success
                alertMessage = success
                    ? NSLocalizedString("Email client opened successfully.", comment: "")
                    : NSLocalizedString("Unable to open email client.", comment: "")
                showAlert = true
            }
        }
    }
}
