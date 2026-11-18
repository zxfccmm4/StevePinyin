import SwiftUI

/// 导入模式选择按钮
/// 用于选择单一、顺序或手动导入模式
struct ImportModeButton: View {
    let mode: AvatarImportMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                modeIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Label(NSLocalizedString("Selected", comment: ""), systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(modeTint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassCapsule()
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 20, interactive: true)
        .scaleEffect(isSelected ? 1.01 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isSelected)
    }

    private var modeIcon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? modeTint : modeTint.opacity(0.12))
                .frame(width: 42, height: 42)

            Image(systemName: iconName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? .white : modeTint)
        }
    }

    private var modeTint: Color {
        switch mode {
        case .single:
            return .blue
        case .sequential:
            return .teal
        case .manual:
            return .orange
        }
    }
    
    private var iconName: String {
        switch mode {
        case .single:
            return "person.crop.circle.fill"
        case .sequential:
            return "arrow.left.arrow.right"
        case .manual:
            return "hand.point.up.fill"
        }
    }
    
    private var title: String {
        switch mode {
        case .single:
            return NSLocalizedString("single_avatar_title", comment: "")
        case .sequential:
            return NSLocalizedString("sequential_avatar_title", comment: "")
        case .manual:
            return NSLocalizedString("manual_avatar_title", comment: "")
        }
    }

    private var description: String {
        switch mode {
        case .single:
            return NSLocalizedString("single_avatar_description", comment: "")
        case .sequential:
            return NSLocalizedString("sequential_avatar_description", comment: "")
        case .manual:
            return NSLocalizedString("manual_avatar_description", comment: "")
        }
    }
}

#Preview {
    Text("ImportModeButton Component")
        .padding()
}
