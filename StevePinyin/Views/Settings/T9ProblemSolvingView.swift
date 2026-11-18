import SwiftUI

struct T9ProblemSolvingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    VStack(spacing: 18) {
                        heroCard
                        issueCard
                        screenshotCard
                        stepsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(NSLocalizedString("T9 Help", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.95), .cyan.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("T9 Search Problem Solving", comment: ""))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(NSLocalizedString("After enabling T9 search, contact names may appear as initials instead of full names on the contact info page.", comment: ""))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                GlassInfoChip(title: NSLocalizedString("T9 Help", comment: ""), systemImage: "keyboard.fill", tint: .blue)
                GlassInfoChip(title: NSLocalizedString("Problem Description", comment: ""), systemImage: "exclamationmark.triangle.fill", tint: .orange)
                GlassInfoChip(title: NSLocalizedString("Solution Steps", comment: ""), systemImage: "checkmark.circle.fill", tint: .green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.18), .cyan.opacity(0.08), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .glassCard(cornerRadius: 28, tint: .blue)
    }

    private var issueCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            T9SectionHeader(
                title: NSLocalizedString("Problem Description", comment: ""),
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            )

            Text(NSLocalizedString("After enabling T9 search, contact names may appear as initials instead of full names on the contact info page.", comment: ""))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            T9SectionHeader(
                title: NSLocalizedString("T9 Help", comment: ""),
                systemImage: "photo.on.rectangle.angled",
                tint: .blue
            )

            Image("StevePinyinT9")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            T9SectionHeader(
                title: NSLocalizedString("Solution Steps", comment: ""),
                systemImage: "checkmark.circle.fill",
                tint: .green
            )

            VStack(spacing: 12) {
                ForEach(Array(stepTexts.enumerated()), id: \.offset) { index, text in
                    T9StepRow(index: index + 1, text: text)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var stepTexts: [String] {
        [
            NSLocalizedString("First, remove all pinyin in StevePinyin", comment: ""),
            NSLocalizedString("Go to Settings > Contacts > Short Name", comment: ""),
            NSLocalizedString("Turn off this option to show full contact names", comment: ""),
            NSLocalizedString("Return to StevePinyin, add pinyin and enable T9 search", comment: ""),
            NSLocalizedString("Now the names should display correctly", comment: ""),
        ]
    }
}

private struct T9SectionHeader: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .glassCapsule()

            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))

            Spacer(minLength: 0)
        }
    }
}


private struct T9StepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.95), .cyan.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}

#Preview {
    T9ProblemSolvingView()
}
