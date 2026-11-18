import SwiftUI
import UIKit

struct AmbientGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.14 : 0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 90)
                .offset(x: -130, y: -250)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.11))
                .frame(width: 380, height: 380)
                .blur(radius: 110)
                .offset(x: 160, y: -160)

            Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 95)
                .offset(x: 120, y: 310)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct GlassSectionCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 18
    var tint: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                tint.map { .regular.tint($0.opacity(0.12)) } ?? .regular,
                in: shape
            )
    }
}

struct GlassActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint.opacity(0.1)).interactive(), in: .rect(cornerRadius: 22))
    }
}

struct GlassRowButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var trailingSystemImage: String = "chevron.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: trailingSystemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct GlassMetricBadge: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct GlassInfoChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCapsule()
    }
}

extension View {
    @ViewBuilder
    func glassCard(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if let tint {
            if interactive {
                self.glassEffect(.regular.tint(tint.opacity(0.12)).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.tint(tint.opacity(0.12)), in: shape)
            }
        } else if interactive {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.glassEffect(.regular, in: shape)
        }
    }

    @ViewBuilder
    func glassCapsule(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if let tint {
            if interactive {
                self.glassEffect(.regular.tint(tint.opacity(0.12)).interactive(), in: Capsule())
            } else {
                self.glassEffect(.regular.tint(tint.opacity(0.12)), in: Capsule())
            }
        } else if interactive {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self.glassEffect(.regular, in: Capsule())
        }
    }
}
