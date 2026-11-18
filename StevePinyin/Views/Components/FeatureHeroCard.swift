import SwiftUI

struct FeatureHeroMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbol: String
    let tint: Color
}

struct FeatureHeroCard: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    let symbol: String
    let gradient: [Color]
    let metrics: [FeatureHeroMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                iconOrb

                VStack(alignment: .leading, spacing: 6) {
                    if let eyebrow, eyebrow.isEmpty == false {
                        Text(eyebrow)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }

            if metrics.isEmpty == false {
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(metrics) { metric in
                            ImportStatusChip(
                                title: metric.title,
                                value: metric.value,
                                systemImage: metric.symbol,
                                tint: metric.tint,
                                fillsWidth: true
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private var iconOrb: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)

            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
