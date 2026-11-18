import SwiftUI

struct ImportEmptyStateView: View {
    let icon: String
    let message: String
    let action: () -> Void
    let actionLabel: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .frame(width: 64, height: 64)
                    .glassCapsule()

                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionLabel)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .glassCapsule(interactive: true)

            Spacer()
        }
        .padding()
        .frame(height: 190)
    }
}

struct ImportStatusChip: View {
    let title: String
    let value: String?
    let systemImage: String
    let tint: Color
    let fillsWidth: Bool
    let fixedWidth: CGFloat?
    let valueLineLimit: Int?

    init(
        title: String,
        value: String? = nil,
        systemImage: String,
        tint: Color = .secondary,
        fillsWidth: Bool = false,
        fixedWidth: CGFloat? = nil,
        valueLineLimit: Int? = 1
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.fillsWidth = fillsWidth
        self.fixedWidth = fixedWidth
        self.valueLineLimit = valueLineLimit
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let value, value.isEmpty == false {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(valueLineLimit)
                        .fixedSize(horizontal: false, vertical: valueLineLimit != 1)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(
            minWidth: fixedWidth,
            maxWidth: fillsWidth ? .infinity : fixedWidth,
            alignment: .leading
        )
        .glassCapsule()
    }
}

struct ImportSubpanel<Content: View>: View {
    let tint: Color
    let content: Content

    init(
        tint: Color = .blue,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(18)
        .glassCard(cornerRadius: 16, tint: tint)
    }
}

struct ImportGlassSearchField: View {
    @Binding var text: String
    let prompt: String
    let tint: Color

    init(
        text: Binding<String>,
        prompt: String,
        tint: Color = .blue
    ) {
        self._text = text
        self.prompt = prompt
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(tint)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)

            if text.isEmpty == false {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 12)
    }
}
