import SwiftUI

/// 头像选择按钮
/// 显示头像和名称，支持选中状态
struct ImportAvatarSelectButton: View {
    let icon: AvatarIcon
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                ImportAvatarImage(icon: icon, size: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.cyan : Color.clear, lineWidth: 2.5)
                    )
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            )
                            .opacity(isSelected ? 1 : 0)
                            .offset(x: 20, y: 20)
                    )
                
                Text(icon.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 74)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.cyan.opacity(0.14), Color.clear, Color.blue.opacity(0.08)]
                                : [Color.white.opacity(0.06), Color.clear, Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 22, interactive: true)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
    }
}

#Preview {
    Text("AvatarSelectButton Component")
        .padding()
}
