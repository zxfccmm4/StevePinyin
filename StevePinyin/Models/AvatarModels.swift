import Foundation

// MARK: - 图标类型枚举
enum IconType: String, Codable, CaseIterable {
    case system = "system"
    case remote = "remote"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .system: return "系统图标"
        case .remote: return "网络图片"
        case .local: return "本地文件"
        }
    }
}

// MARK: - 统一的图标模型
struct Icon: Identifiable, Codable, Equatable, Hashable {
    let name: String
    let url: String
    
    var id: String { url }
    
    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(name)
    }
    
    // MARK: - 类型判断
    var type: IconType {
        if url.hasPrefix("http") {
            return .remote
        } else if url.hasPrefix("system:") {
            return .system
        } else {
            return .local
        }
    }
    
    var isSystemIcon: Bool {
        return type == .system
    }
    
    var isRemoteIcon: Bool {
        return type == .remote
    }
    
    var systemSymbolName: String? {
        guard isSystemIcon else { return nil }
        return url.replacingOccurrences(of: "system:", with: "")
    }

    var resolvedSystemSymbolName: String {
        systemSymbolName ?? url
    }
    
    var remoteURL: URL? {
        guard isRemoteIcon else { return nil }
        return URL(string: url)
    }
}

// MARK: - AvatarIcon 类型别名（保持向后兼容）
typealias AvatarIcon = Icon

// MARK: - 头像包模型
struct AvatarPackage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let icons: [Icon]
    let isDefault: Bool
    let createdAt: Date
    
    init(id: String, name: String, description: String, icons: [Icon], isDefault: Bool, createdAt: Date) {
        self.id = id
        self.name = name
        self.description = description
        self.icons = icons
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
    
 
    
    // MARK: - Equatable
    static func == (lhs: AvatarPackage, rhs: AvatarPackage) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - IconPackage (保持向后兼容)
struct IconPackage: Codable {
    let name: String
    let description: String
    let icons: [Icon]
    
    init(name: String, description: String, icons: [Icon]) {
        self.name = name
        self.description = description
        self.icons = icons
    }
}

// MARK: - 头像导入模式
enum AvatarImportMode: String, CaseIterable, Codable {
    case single = "single"
    case sequential = "sequential"
    case manual = "manual"
    
    var title: String {
        switch self {
        case .single: return NSLocalizedString("avatar_mode_single_title", comment: "Title for single avatar mode")
        case .sequential: return NSLocalizedString("avatar_mode_sequential_title", comment: "Title for sequential avatar mode")
        case .manual: return NSLocalizedString("avatar_mode_manual_title", comment: "Title for manual avatar mode")
        }
    }
    
    var description: String {
        switch self {
        case .single: return NSLocalizedString("avatar_mode_single_desc", comment: "Description for single avatar mode")
        case .sequential: return NSLocalizedString("avatar_mode_sequential_desc", comment: "Description for sequential avatar mode")
        case .manual: return NSLocalizedString("avatar_mode_manual_desc", comment: "Description for manual avatar mode")
        }
    }
    
    var icon: String {
        switch self {
        case .single: return "person.crop.circle.fill"
        case .sequential: return "arrow.triangle.2.circlepath"
        case .manual: return "hand.tap.fill"
        }
    }
    
    var systemImageName: String {
        return icon
    }
}
