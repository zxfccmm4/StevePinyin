import SwiftUI

struct PrivacyPolicyView: View {
    var dismissAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    VStack(spacing: 18) {
                        heroCard
                        overviewCard
                        featuresCard
                        commitmentCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(NSLocalizedString("Privacy Policy", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Done", comment: "")) {
                        dismissAction()
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
                                colors: [.green.opacity(0.95), .mint.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Privacy Protection", comment: ""))
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Text(NSLocalizedString("Your data security is our top priority", comment: ""))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                GlassInfoChip(title: NSLocalizedString("Privacy Policy", comment: ""), systemImage: "checkmark.shield.fill", tint: .green)
                GlassInfoChip(title: NSLocalizedString("100% Local Processing", comment: ""), systemImage: "iphone", tint: .blue)
                GlassInfoChip(title: NSLocalizedString("Data Protection Commitment", comment: ""), systemImage: "lock.fill", tint: .orange)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0.16), .mint.opacity(0.08), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .glassCard(cornerRadius: 28, tint: .green)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            PrivacySectionHeader(
                title: NSLocalizedString("Privacy Policy Overview", comment: ""),
                systemImage: "info.circle.fill",
                tint: .blue
            )

            Text(NSLocalizedString("privacy_intro_text", comment: ""))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            PrivacySectionHeader(
                title: NSLocalizedString("Privacy Protection Features", comment: ""),
                systemImage: "list.bullet.circle.fill",
                tint: .purple
            )

            VStack(spacing: 12) {
                PrivacyFeatureRow(text: NSLocalizedString("privacy_feature_1", comment: ""), index: 1, tint: .blue)
                PrivacyFeatureRow(text: NSLocalizedString("privacy_feature_2", comment: ""), index: 2, tint: .purple)
                PrivacyFeatureRow(text: NSLocalizedString("privacy_feature_3", comment: ""), index: 3, tint: .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }

    private var commitmentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            PrivacySectionHeader(
                title: NSLocalizedString("Data Protection Commitment", comment: ""),
                systemImage: "checkmark.shield.fill",
                tint: .green
            )

            HStack(spacing: 10) {
                PrivacyHighlightRow(
                    title: NSLocalizedString("100% Local Processing", comment: ""),
                    systemImage: "iphone",
                    tint: .green
                )
            }

            Text(NSLocalizedString("privacy_protection_text", comment: ""))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 26)
    }
}

private struct PrivacySectionHeader: View {
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


private struct PrivacyFeatureRow: View {
    let text: String
    let index: Int
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.45)],
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

private struct PrivacyHighlightRow: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCapsule()
    }
}

#Preview {
    PrivacyPolicyView {}
}
