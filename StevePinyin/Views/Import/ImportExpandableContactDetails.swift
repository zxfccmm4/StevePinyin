import Contacts
import SwiftUI

struct ImportExpandableContactDetails: View {
    let contact: CNContact

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal)

            if contact.isKeyAvailable(CNContactPhoneNumbersKey), contact.phoneNumbers.isEmpty == false {
                ImportContactInfoSection(
                    title: NSLocalizedString("Phone", comment: ""),
                    systemImage: "phone.fill"
                ) {
                    ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                        HStack(spacing: 8) {
                            Text(phone.value.stringValue)
                                .font(.subheadline)
                        }
                    }
                }
            }

            if contact.isKeyAvailable(CNContactEmailAddressesKey), contact.emailAddresses.isEmpty == false {
                ImportContactInfoSection(
                    title: NSLocalizedString("Email", comment: ""),
                    systemImage: "envelope.fill"
                ) {
                    ForEach(contact.emailAddresses, id: \.identifier) { email in
                        HStack(spacing: 8) {
                            Text(email.value as String)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
}

private struct ImportContactInfoSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            content
        }
        .padding(.horizontal)
    }
}
