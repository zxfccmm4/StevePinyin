import SwiftUI

struct ContactsProcessingView: View {
    let processedCount: Int
    let totalCount: Int
    @State private var isAnimating = false

    var body: some View {
        ImportSubpanel(tint: .blue) {
            VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(isAnimating ? 1.2 : 0.9)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                ForEach(0 ..< 2) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 160 + CGFloat(index * 30), height: 160 + CGFloat(index * 30))
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }

                Circle()
                    .trim(from: 0, to: CGFloat(processedCount) / CGFloat(max(1, totalCount)))
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: processedCount)

                VStack(spacing: 8) {
                    Text("\(Int(Float(processedCount) / Float(max(1, totalCount)) * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("\(processedCount)/\(totalCount)")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
            }

            VStack(spacing: 16) {
                Text(NSLocalizedString("Processing Contacts", comment: ""))
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(NSLocalizedString("Please wait while we add pinyin to your contacts", comment: ""))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ContactsPinyinFormatSelectionSheet: View {
    let handleSelection: (PinyinFormat) -> Void
    @State private var selectedOptionID: String?

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 14) {
                    ContactsFormatHeroCard(
                        title: ContactsPinyinSectionStrings.selectPinyinFormat,
                        subtitle: ContactsPinyinSectionStrings.selectPinyinFormatSubtitle,
                        systemImage: "wand.and.rays",
                        tint: .blue
                    )

                    VStack(spacing: 12) {
                        ContactsFormatOptionButton(
                            id: "withTone",
                            title: ContactsPinyinSectionStrings.withToneMarks,
                            description: ContactsPinyinSectionStrings.withToneMarksDescription,
                            example: "Qiáo Bāng Zhǔ",
                            icon: "music.note",
                            gradient: [.orange, .pink],
                            isLoading: selectedOptionID == "withTone"
                        ) {
                            selectOption(id: "withTone") {
                                handleSelection(.withTone)
                            }
                        }

                        ContactsFormatOptionButton(
                            id: "plainLetter",
                            title: ContactsPinyinSectionStrings.plainLetters,
                            description: ContactsPinyinSectionStrings.plainLettersDescription,
                            example: "Qiao Bang Zhu",
                            icon: "textformat",
                            gradient: [.blue, .cyan],
                            isLoading: selectedOptionID == "plainLetter"
                        ) {
                            selectOption(id: "plainLetter") {
                                handleSelection(.plainLetter)
                            }
                        }

                        ContactsFormatOptionButton(
                            id: "firstLetter",
                            title: ContactsPinyinSectionStrings.firstLetters,
                            description: ContactsPinyinSectionStrings.firstLettersDescription,
                            example: "Q B Z",
                            icon: "text.quote",
                            gradient: [.purple, .indigo],
                            isLoading: selectedOptionID == "firstLetter"
                        ) {
                            selectOption(id: "firstLetter") {
                                handleSelection(.firstLetter)
                            }
                        }

                        ContactsFormatOptionButton(
                            id: "plainNoSpace",
                            title: ContactsPinyinSectionStrings.plainLettersNoSpace,
                            description: ContactsPinyinSectionStrings.plainLettersNoSpaceDescription,
                            example: "QiaoBangZhu",
                            icon: "character",
                            gradient: [.green, .mint],
                            isLoading: selectedOptionID == "plainNoSpace"
                        ) {
                            selectOption(id: "plainNoSpace") {
                                handleSelection(.plainNoSpace)
                            }
                        }

                        ContactsFormatOptionButton(
                            id: "firstNoSpace",
                            title: ContactsPinyinSectionStrings.firstLettersNoSpace,
                            description: ContactsPinyinSectionStrings.firstLettersNoSpaceDescription,
                            example: "QBZ",
                            icon: "textformat.size.smaller",
                            gradient: [.pink, .red],
                            isLoading: selectedOptionID == "firstNoSpace"
                        ) {
                            selectOption(id: "firstNoSpace") {
                                handleSelection(.firstNoSpace)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AmbientGlassBackdrop())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectOption(id: String, action: @escaping () -> Void) {
        guard selectedOptionID == nil else { return }
        selectedOptionID = id

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                action()
            }

            try? await Task.sleep(for: .milliseconds(250))
            await MainActor.run {
                if selectedOptionID == id {
                    selectedOptionID = nil
                }
            }
        }
    }
}

struct ContactsT9FormatSelectionSheet: View {
    let handleT9Selection: (PinyinFormat) -> Void
    @State private var selectedOptionID: String?

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 14) {
                    ContactsFormatHeroCard(
                        title: ContactsPinyinSectionStrings.selectT9SearchFormat,
                        subtitle: ContactsPinyinSectionStrings.selectT9SearchFormatSubtitle,
                        systemImage: "keyboard",
                        tint: .green
                    )

                    VStack(spacing: 12) {
                        ContactsFormatOptionButton(
                            id: "plainNoSpace",
                            title: ContactsPinyinSectionStrings.plainLettersNoSpace,
                            description: ContactsPinyinSectionStrings.fullPinyinForT9Search,
                            example: "74262264948-QiaoBangZhu",
                            icon: "textformat.abc",
                            gradient: [.orange, .pink],
                            isLoading: selectedOptionID == "plainNoSpace"
                        ) {
                            selectOption(id: "plainNoSpace") {
                                handleT9Selection(.plainNoSpace)
                            }
                        }

                        ContactsFormatOptionButton(
                            id: "firstNoSpace",
                            title: ContactsPinyinSectionStrings.firstLettersNoSpace,
                            description: ContactsPinyinSectionStrings.initialLettersForT9Search,
                            example: "729-QBZ",
                            icon: "textformat.size.smaller",
                            gradient: [.pink, .purple],
                            isLoading: selectedOptionID == "firstNoSpace"
                        ) {
                            selectOption(id: "firstNoSpace") {
                                handleT9Selection(.firstNoSpace)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AmbientGlassBackdrop())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectOption(id: String, action: @escaping () -> Void) {
        guard selectedOptionID == nil else { return }
        selectedOptionID = id

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run {
                action()
            }

            try? await Task.sleep(for: .milliseconds(250))
            await MainActor.run {
                if selectedOptionID == id {
                    selectedOptionID = nil
                }
            }
        }
    }
}

private struct ContactsFormatHeroCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.95), tint.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)

                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                GlassInfoChip(title: ContactsPinyinSectionStrings.fast, systemImage: "bolt.fill", tint: tint)
                GlassInfoChip(title: ContactsPinyinSectionStrings.searchable, systemImage: "magnifyingglass", tint: .blue)
                GlassInfoChip(title: ContactsPinyinSectionStrings.consistent, systemImage: "line.3.horizontal.decrease.circle", tint: .orange)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 24, tint: tint)
    }
}

private enum ContactsPinyinSectionStrings {
    static let selectPinyinFormat = String(localized: "Select Pinyin Format")
    static let selectPinyinFormatSubtitle = String(
        localized: "Choose how Chinese names should be transformed across your contacts."
    )
    static let withToneMarks = String(localized: "With Tone Marks")
    static let withToneMarksDescription = String(localized: "Preserves original tone marks")
    static let plainLetters = String(localized: "Plain Letters")
    static let plainLettersDescription = String(localized: "Simple pinyin with spaces")
    static let firstLetters = String(localized: "First Letters")
    static let firstLettersDescription = String(localized: "Initial letters with spaces")
    static let plainLettersNoSpace = String(localized: "Plain Letters (No Space)")
    static let plainLettersNoSpaceDescription = String(localized: "Continuous pinyin")
    static let firstLettersNoSpace = String(localized: "First Letters (No Space)")
    static let firstLettersNoSpaceDescription = String(localized: "Continuous initials")
    static let selectT9SearchFormat = String(localized: "Select T9 Search Format")
    static let selectT9SearchFormatSubtitle = String(
        localized: "Pick the indexing style that should power number-keyboard searching."
    )
    static let fullPinyinForT9Search = String(localized: "Full pinyin without spaces for T9 search")
    static let initialLettersForT9Search = String(localized: "Initial letters only for T9 search")
    static let fast = String(localized: "Fast")
    static let searchable = String(localized: "Searchable")
    static let consistent = String(localized: "Consistent")
}

struct ContactsFormatOptionButton: View {
    let id: String
    let title: String
    let description: String
    let example: String
    let icon: String
    let gradient: [Color]
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [gradient[0].opacity(0.95), gradient[1].opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline.weight(.semibold))

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(example)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(gradient[0])
                }

                Spacer()

                trailingIndicator
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .glassCard(cornerRadius: 22, interactive: true)
        .opacity(isLoading ? 0.92 : 1)
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        if isLoading {
            ZStack {
                Circle()
                    .stroke(gradient[0].opacity(0.16), lineWidth: 4)
                    .frame(width: 34, height: 34)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(gradient[0])
                    .scaleEffect(0.9)
            }
            .frame(width: 34, height: 34)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(gradient[0])

                Capsule()
                    .fill(gradient[0].opacity(0.85))
                    .frame(width: 6, height: 28)
            }
        }
    }
}


#Preview {
    ContactsProcessingView(processedCount: 42, totalCount: 100)
        .padding()
}
