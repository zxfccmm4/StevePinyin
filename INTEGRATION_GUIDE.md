# StevePinyin × WWDC26 Phase 1+2 集成指南
> [!NOTE]
> 本文档为 2026-06 Phase 1+2 阶段的历史记录，所述集成步骤已全部完成并被后续重构取代。
> 当前项目终态见 [WWDC26_IMPLEMENTATION_SUMMARY.md](WWDC26_IMPLEMENTATION_SUMMARY.md)。


**生成时间**: 2026-06-24  
**状态**: ✅ 代码已生成，待集成

---

## 📁 生成的文件清单

### 1. App Intents 模块 (`Intents/`)
| 文件 | 说明 |
|------|------|
| `AvatarPackageEntity.swift` | 头像包实体定义（AppEntity） |
| `ImportAvatarsIntent.swift` | 导入头像 Intent |
| `MatchAvatarsIntent.swift` | 匹配头像 Intent |
| `CheckDuplicateContactsIntent.swift` | 检查重复联系人 Intent |
| `StevePinyinShortcuts.swift` | 快捷指令注册 |
| `IntentRouter.swift` | Intent 路由处理 |

### 2. 性能监控模块 (`Services/Performance/`)
| 文件 | 说明 |
|------|------|
| `PerformanceMonitor.swift` | MetricKit + signpost 监控服务 |

### 3. 服务扩展
| 文件 | 说明 |
|------|------|
| `Services/AvatarPackageService+Intents.swift` | 为 Intents 扩展的头像包服务 |

### 4. 视图
| 文件 | 说明 |
|------|------|
| `Views/PerformanceDebugView.swift` | 性能监控调试页面 |

### 5. 修改的现有文件
| 文件 | 修改内容 |
|------|----------|
| `StevePinyinApp.swift` | 添加性能监控启动、Environment 注入 |
| `MainTabView+Intents.swift` | Intent 路由监听和处理（新增扩展文件） |

### 6. 配置文件
| 文件 | 说明 |
|------|------|
| `Resources/Info+Intents.plist` | App Intents 所需的 Info.plist 条目 |

---

## 🚀 快速集成步骤

### 步骤 1: 复制文件到项目

```bash
# 进入 StevePinyin 项目目录
cd /path/to/StevePinyin

# 创建目录
mkdir -p StevePinyin/Intents
mkdir -p StevePinyin/Services/Performance

# 复制生成的文件
cp /path/to/generated/Intents/*.swift StevePinyin/Intents/
cp /path/to/generated/Services/Performance/*.swift StevePinyin/Services/Performance/
cp /path/to/generated/Services/AvatarPackageService+Intents.swift StevePinyin/Services/
cp /path/to/generated/Views/PerformanceDebugView.swift StevePinyin/Views/
cp /path/to/generated/MainTabView+Intents.swift StevePinyin/
```

### 步骤 2: 更新 Info.plist

打开 `StevePinyin/Resources/Info.plist`，添加以下条目：

```xml
<key>NSUserActivityTypes</key>
<array>
    <string>ImportAvatarsIntent</string>
    <string>MatchAvatarsIntent</string>
    <string>CheckDuplicateContactsIntent</string>
</array>

<key>NSSiriUsageDescription</key>
<string>StevePinyin 需要 Siri 权限来执行头像导入、匹配等快捷操作。</string>
```

### 步骤 3: 修改 MainTabView

在 `MainTabView.swift` 的 body 末尾添加 Intent 支持：

```swift
// 在 body 的最后一个 modifier 后添加
.withIntentHandling()
```

或者将现有的 MainTabView 代码替换为支持 Intent 的版本。

### 步骤 4: 更新项目设置

1. **部署目标**: 修改为 iOS 27.0（或保持 16.0，使用条件编译）
2. **添加框架**:
   - `AppIntents.framework`
   - `MetricKit.framework`

### 步骤 5: 构建验证

```bash
xcodebuild -project StevePinyin.xcodeproj -scheme StevePinyin -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build
```

---

## 🎯 功能验证清单

### App Intents
- [ ] 可以说 "用 StevePinyin 导入头像" 触发 Siri
- [ ] 快捷指令 App 中显示 StevePinyin 的动作
- [ ] 执行 Intent 后正确跳转到导入页面

### Performance Monitor
- [ ] 启动后自动开始监控
- [ ] 批量导入时记录 signpost 事件
- [ ] PerformanceDebugView 显示监控数据

---

## 🔧 自定义配置

### 1. 调整头像包数据源

修改 `AvatarPackageService+Intents.swift` 中的 `getAllPackages()`：

```swift
func getAllPackages() async -> [IconPackage] {
    // 替换为你的实际数据源
    return await yourPackageService.fetchPackages()
}
```

### 2. 添加更多 Intent

可以参考 `ImportAvatarsIntent.swift` 创建新的 Intent：

```swift
struct YourNewIntent: AppIntent {
    static let title: LocalizedStringResource = "你的操作"
    
    func perform() async throws -> some IntentResult {
        // 实现逻辑
        return .result()
    }
}
```

### 3. 配置性能监控阈值

在 `PerformanceMonitor.swift` 中调整阈值：

```swift
// 修改批量导入的预期耗时阈值
if durationMs > 30000 {  // 30秒
    record(title: "SlowImport", detail: "导入耗时过长")
}
```

---

## ⚠️ 已知限制

### 模拟器 vs 真机

| 功能 | 模拟器 | 真机 |
|------|--------|------|
| App Intents 基本功能 | ✅ | ✅ |
| Siri 语音触发 | ❌（需测试） | ✅ |
| MetricKit 系统报告 | ⚠️（延迟） | ✅ |
| signpost 事件 | ✅ | ✅ |

### iOS 版本兼容性

代码使用了条件编译来保持向后兼容：

```swift
if #available(iOS 27.0, *) {
    // 使用新的 MetricManager API
} else {
    // 降级到旧的 MXMetricManager
}
```

---

## 📚 参考文档

- [WWDC26 Sample Code Library](https://developer.apple.com/documentation/samplecode/)
- [Adopting App Intents](https://developer.apple.com/documentation/AppIntents/adopting-app-intents-to-support-system-experiences)
- [MetricKit Documentation](https://developer.apple.com/documentation/metrickit)

---

## 🆘 故障排除

### "Cannot find 'MetricManager' in scope"
- 确保部署目标设置为 iOS 27.0
- 确保已导入 `MetricKit` 框架

### App Intents 不显示在快捷指令中
- 检查 `StevePinyinShortcuts.swift` 是否正确添加到目标
- 重新构建并安装 App
- 等待系统索引（可能需要几分钟）

### PerformanceMonitor 事件不显示
- 确认调用了 `startMonitoring()`
- 检查 OSLog 是否被过滤

---

**下一步**: 完成集成后，可以继续 Phase 3（SwiftUI 交互升级）或 Phase 4（Apple Intelligence）。
