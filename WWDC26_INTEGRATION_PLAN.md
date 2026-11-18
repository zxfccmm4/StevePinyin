# StevePinyin × WWDC26 新功能集成实施计划

**文档版本**: 1.0  
**创建日期**: 2026-06-24  
**预计总工期**: 5-8 个工作日  
**目标部署版本**: iOS 27.0（需评估升级影响）

---

## 1. 项目现状分析

### 1.1 业务特征
| 维度 | 现状 |
|------|------|
| 核心功能 | 联系人头像批量导入、匹配、管理 |
| 用户场景 | 批量操作、重复执行、需要效率 |
| 性能敏感点 | 批量联系人写入、头像数据处理 |
| 当前架构 | UseCase + ViewModel + Service 分层清晰 |
| 部署目标 | iOS 16.0 |
| 测试覆盖 | UseCase 层有单元测试 |

### 1.2 最适合的 WWDC26 新功能

| 功能 | 契合度 | 用户价值 | 工程价值 | 优先级 |
|------|--------|----------|----------|--------|
| **App Intents** | ⭐⭐⭐⭐⭐ | 让用户通过 Siri/快捷指令执行导入、匹配 | 扩展系统入口 | **P0** |
| **MetricKit** | ⭐⭐⭐⭐⭐ | 监控批量导入性能、定位真实用户问题 | 工程优化依据 | **P1** |
| **SwiftUI 新交互** | ⭐⭐⭐⭐ | 拖放排序、新 Sheet 动画提升体验 | 体验升级 | **P2** |
| **Apple Intelligence** | ⭐⭐⭐ | 头像质量检测、智能匹配推荐 | 差异化功能 | **P3** |
| **DeclaredAgeRange** | ⭐ | 不适用（非社交/内容类应用） | — | 跳过 |

---

## 2. 实施路线图

```
Week 1                    Week 2
────────────────────────────────────────────────────────
Phase 1    Phase 2       Phase 3       Phase 4
准备       App Intents   MetricKit     SwiftUI 优化
1 天       2-3 天        1-2 天        1 天
```

---

## 3. Phase 1: 基础准备（1 天）

### 3.1 目标
- 升级部署目标至 iOS 27.0
- 导入所需框架
- 建立工程结构

### 3.2 具体步骤

#### Step 1.1: 升级部署目标
```bash
# 修改 project.pbxproj
IPHONEOS_DEPLOYMENT_TARGET = 27.0;
```

**风险评估**:
- 需确认现有 iOS 16 API 在 iOS 27 的兼容性
- Swift 5.0 → Swift 6.0 可能存在并发检查变化

#### Step 1.2: 新增框架依赖
```swift
// 在 StevePinyinApp.swift 或全局导入
import AppIntents        // P0
import MetricKit         // P1
import FoundationModels  // P3（可选）
```

#### Step 1.3: 建立目录结构
```
StevePinyin/
├── Intents/                 # 新增：App Intents
│   ├── ImportAvatarsIntent.swift
│   ├── MatchAvatarsIntent.swift
│   └── CheckDuplicateContactsIntent.swift
├── Services/
│   ├── IntelligenceService.swift    # 新增：Apple Intelligence
│   └── PerformanceMonitor.swift     # 新增：MetricKit 监控
└── AppShortcuts.swift       # 新增：快捷指令注册
```

### 3.3 验收标准
- [ ] 项目设置中部署目标显示 iOS 27.0
- [ ] Build 通过，无新增 warning
- [ ] 新目录结构建立完成

---

## 4. Phase 2: App Intents 集成（2-3 天）

### 4.1 目标
让用户通过 Siri、快捷指令、Spotlight 直接执行 StevePinyin 的核心功能。

### 4.2 设计原则
- **薄封装原则**: Intent 只做参数解析和路由，业务逻辑复用现有 UseCase
- **渐进暴露**: 先实现 3 个最高频操作，不暴露全部功能
- **系统体验优先**: 考虑 Siri 语音交互的特点，提供自然的说法

### 4.3 具体实现

#### Intent 1: ImportAvatarsIntent
```swift
// Intents/ImportAvatarsIntent.swift
import AppIntents

struct ImportAvatarsIntent: AppIntent {
    static let title: LocalizedStringResource = "导入联系人头像"
    static let description = IntentDescription("从头像包导入联系人头像")
    static let openAppWhenRun = true
    
    @Parameter(title: "头像包", requestValueDialog: "要导入哪个头像包？")
    var package: AvatarPackageEntity?
    
    func perform() async throws -> some IntentResult & ReturnsValue<ImportResultEntity> {
        // 1. 解析参数
        // 2. 调用 ContactAvatarImportUseCase
        // 3. 返回结果
    }
}
```

**用户语音示例**:
- "用 StevePinyin 导入头像"
- "给我的联系人导入头像包"

#### Intent 2: MatchAvatarsIntent
```swift
// Intents/MatchAvatarsIntent.swift
struct MatchAvatarsIntent: AppIntent {
    static let title: LocalizedStringResource = "匹配联系人头像"
    static let openAppWhenRun = false  // 纯后台执行
    
    func perform() async throws -> some IntentResult {
        // 调用 PrepareAvatarMatchesUseCase
        // 返回匹配结果摘要
    }
}
```

**用户语音示例**:
- "重新匹配我的联系人头像"
- "更新联系人头像"

#### Intent 3: CheckDuplicateContactsIntent
```swift
// Intents/CheckDuplicateContactsIntent.swift
struct CheckDuplicateContactsIntent: AppIntent {
    static let title: LocalizedStringResource = "检查重复联系人"
    static let openAppWhenRun = true
    
    func perform() async throws -> some IntentResult {
        // 调用 DuplicateContactDetectionUseCase
    }
}
```

#### Entity 定义
```swift
// Intents/AvatarPackageEntity.swift
struct AvatarPackageEntity: AppEntity, Identifiable {
    let id: String
    let name: String
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "头像包"
    static let defaultQuery = AvatarPackageQuery()
}

struct AvatarPackageQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AvatarPackageEntity] {
        // 从 AvatarPackageService 查询
    }
    
    func suggestedEntities() async throws -> [AvatarPackageEntity] {
        // 返回最近使用的头像包
    }
}
```

#### AppShortcuts 注册
```swift
// AppShortcuts.swift
struct StevePinyinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportAvatarsIntent(),
            phrases: [
                "用 \(.applicationName) 导入头像",
                "给我的联系人导入头像",
            ],
            shortTitle: "导入头像",
            systemImageName: "person.crop.circle.badge.plus"
        )
        
        AppShortcut(
            intent: MatchAvatarsIntent(),
            phrases: [
                "重新匹配 \(.applicationName) 头像",
                "更新我的联系人头像",
            ],
            shortTitle: "匹配头像",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
```

### 4.4 Intent 路由处理
在 `StevePinyinApp.swift` 或 `MainTabView` 中增加 Intent 路由：

```swift
// 新增：IntentRouter.swift
@Observable
@MainActor
final class IntentRouter {
    var pendingIntent: AppIntent?
    var navigationTarget: NavigationTarget?
    
    enum NavigationTarget {
        case importAvatars(packageID: String?)
        case matchResults
        case duplicateContacts
    }
    
    func handle(_ intent: AppIntent) {
        switch intent {
        case let intent as ImportAvatarsIntent:
            navigationTarget = .importAvatars(packageID: intent.package?.id)
        // ...
        }
    }
}
```

### 4.5 涉及的现有文件修改
| 文件 | 修改内容 |
|------|----------|
| `StevePinyinApp.swift` | 注入 IntentRouter，处理启动时的 Intent |
| `MainTabView.swift` | 监听 navigationTarget，自动跳转对应 Tab |
| `ImportAvatarsViewModel.swift` | 支持从 Intent 参数初始化 |

### 4.6 验收标准
- [ ] 可以说 "用 StevePinyin 导入头像" 触发 Siri 执行
- [ ] 快捷指令 App 中能看到 StevePinyin 的动作
- [ ] Intent 执行后正确跳转到对应页面
- [ ] 单元测试覆盖 Intent 参数解析逻辑

### 4.7 测试要点
```swift
// 新增：ImportAvatarsIntentTests.swift
func testImportIntentParameterParsing() async {
    let intent = ImportAvatarsIntent()
    intent.package = AvatarPackageEntity(id: "test-package", name: "测试包")
    
    let result = try await intent.perform()
    
    XCTAssertEqual(result.value.packageID, "test-package")
}
```

---

## 5. Phase 3: MetricKit 性能监控（1-2 天）

### 5.1 目标
监控批量导入、匹配等关键操作的性能，发现真实用户设备上的性能问题。

### 5.2 监控范围

| 关键路径 | 监控指标 | 预期阈值 |
|----------|----------|----------|
| 批量头像导入 | 耗时、内存峰值、成功率 | < 30s/100人 |
| 头像匹配 | 耗时、匹配准确率 | < 5s/100人 |
| 重复检测 | 耗时、检测结果数 | < 3s/1000人 |
| 头像包加载 | 耗时、内存占用 | < 1s |

### 5.3 具体实现

#### PerformanceMonitor 服务
```swift
// Services/PerformanceMonitor.swift
import MetricKit
import os

@Observable
@MainActor
final class PerformanceMonitor {
    private let metricManager = MetricManager()
    private let logger = Logger(subsystem: "com.stevezhou.StevePinyin", category: "Performance")
    private let signpostLog = OSLog(subsystem: "com.stevezhou.StevePinyin", category: "Signpost")
    
    var events: [PerformanceEvent] = []
    var metricReportCount = 0
    var diagnosticReportCount = 0
    
    func startMonitoring() {
        // 订阅系统指标报告
        Task {
            for await report in metricManager.metricReports {
                await handleMetricReport(report)
            }
        }
        
        // 订阅诊断报告
        Task {
            for await report in metricManager.diagnosticReports {
                await handleDiagnosticReport(report)
            }
        }
    }
    
    // MARK: - Signpost 标记关键流程
    
    func trackBatchImport<T>(
        contactCount: Int,
        operation: () async throws -> T
    ) async rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)
        
        mxSignpost(.begin, log: signpostLog, name: "BatchAvatarImport", signpostID: signpostID, 
                   "count=%{public}d", contactCount)
        
        let startTime = ContinuousClock.now
        
        do {
            let result = try await operation()
            let duration = startTime.duration(to: .now)
            
            mxSignpost(.end, log: signpostLog, name: "BatchAvatarImport", signpostID: signpostID)
            
            record(event: "BatchImportSuccess", 
                   detail: "导入 \(contactCount) 个联系人，耗时 \(duration)",
                   metadata: ["count": contactCount, "duration_ms": duration.milliseconds])
            
            return result
        } catch {
            mxSignpost(.end, log: signpostLog, name: "BatchAvatarImport", signpostID: signpostID)
            
            record(event: "BatchImportFailed",
                   detail: "导入失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - 启动任务追踪（iOS 27 新 API）
    
    func trackLaunchTask<T>(id: String, operation: () async throws -> T) async rethrows -> T {
        try await metricManager.trackLaunchTask(id: LaunchTaskID(rawValue: id)) { error in
            self.logger.error("Launch task tracking error: \(error)")
        } operation: {
            try await operation()
        }
    }
    
    // ... 其他监控方法
}
```

#### 在 UseCase 中集成
```swift
// UseCases/ContactAvatarImportUseCase.swift
func importAvatars(...) async -> AvatarImportResult {
    await PerformanceMonitor.shared.trackBatchImport(contactCount: matches.count) {
        // 原有导入逻辑
    }
}
```

### 5.4 性能仪表板（可选）
在设置页面增加调试入口，显示最近的性能事件：

```swift
// Views/PerformanceDebugView.swift
struct PerformanceDebugView: View {
    @State private var monitor = PerformanceMonitor.shared
    
    var body: some View {
        List(monitor.events) { event in
            VStack(alignment: .leading) {
                Text(event.title)
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

### 5.5 验收标准
- [ ] Xcode Instruments 中能看到 StevePinyin 的 signpost 事件
- [ ] 批量导入后性能事件被正确记录
- [ ] 在 Xcode Organizer 中能看到 MetricKit 报告（发布后）

### 5.6 当前实施状态（2026-06-24）
- [x] `PerformanceMonitor` 已订阅 MetricKit 系统报告与诊断报告，并通过 `mxSignpost` 标记关键流程。
- [x] 批量头像导入、头像匹配、重复联系人检测、头像包加载已接入统一性能追踪。
- [x] 性能事件记录包含耗时、阈值、是否达标和业务上下文元数据。
- [x] 新增单元测试覆盖异步埋点、同步埋点和事件容量裁剪。
- [ ] Instruments signpost 可见性仍需在 Xcode Instruments 中人工验证。
- [ ] Organizer MetricKit 报告需发布后等待系统投递验证。

---

## 6. Phase 4: SwiftUI 交互升级（1 天）

### 6.1 目标
利用 iOS 27 新的 SwiftUI 特性，提升头像选择、匹配确认等交互体验。

### 6.2 具体改进

#### 改进 1: 头像匹配结果拖放排序
```swift
// Views/AvatarMatchResultView.swift
struct AvatarMatchResultView: View {
    @State private var matches: [AvatarMatch]
    
    var body: some View {
        List {
            ForEach($matches) { $match in
                AvatarMatchRow(match: match)
                    .draggable(match.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        // 处理拖放排序
                    }
            }
        }
    }
}
```

#### 改进 2: 批量导入确认 Sheet（新动画）
```swift
// Views/ImportConfirmationSheet.swift
.sheet(item: $viewModel.confirmationState) { state in
    ImportConfirmationSheet(state: state)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

#### 改进 3: 联系人列表分段模式
```swift
// Views/ContactListView.swift
@State private var filterMode: FilterMode = .all

var body: some View {
    List(filteredContacts) { contact in
        ContactRow(contact: contact)
    }
    .toolbar {
        Picker("筛选", selection: $filterMode) {
            Text("全部").tag(FilterMode.all)
            Text("已匹配").tag(FilterMode.matched)
            Text("未匹配").tag(FilterMode.unmatched)
        }
        .pickerStyle(.segmented)
    }
}
```

### 6.3 验收标准
- [ ] 头像匹配结果支持拖放调整顺序
- [ ] Sheet 使用新的 presentationDetents API
- [ ] 分段筛选器正常工作

---

## 7. Phase 5: Apple Intelligence（可选，2-3 天）

### 7.1 应用场景
基于优先级评估，建议仅在资源充足时实施。

#### 场景 1: 头像质量检测
```swift
// Services/IntelligenceService.swift
func analyzeAvatarQuality(imageData: Data) async -> QualityAssessment {
    let session = LanguageModelSession(
        model: .default,
        instructions: "分析头像图片质量，返回模糊、过暗、构图等问题的评分"
    )
    
    // 实际调用模型...
}
```

**用户价值**: 提前发现低质量头像，避免导入后效果差

#### 场景 2: 智能匹配推荐
分析联系人姓名、公司信息，智能推荐最合适的头像。

### 7.2 技术约束
- 需要 Apple Intelligence 可用（设备、地区、账户状态）
- 建议采用"演示模式 + 系统模式"双路径（参考 WWDC26IntelligenceDemo）

### 7.3 当前实施状态（2026-06-24）
- [x] 新增 `AvatarIntelligenceService`，提供演示模式下的头像质量检测与智能推荐排序。
- [x] 新增 `BuildAvatarRecommendationsUseCase`，将推荐结果包装成业务层可复用接口。
- [x] 头像质量检测覆盖分辨率、数据体积、亮度、对比度和头像比例，并返回可解释问题与建议。
- [x] 智能推荐基于联系人姓名、昵称、拼音、组织名与头像名称/URL 的关键词相关性生成推荐分。
- [x] 手动选择流程已展示智能推荐，并支持一键应用推荐头像。
- [x] 新增单元测试覆盖高质量头像、低质量头像、推荐排序和跳过已有头像联系人。
- [x] 新增 ViewModel 测试覆盖推荐缓存与一键应用推荐。
- [ ] 系统模式仍预留给 Foundation Models / Apple Intelligence，需在满足设备、地区、账户和模型资产条件后接入并真机验证。

---

## 8. 风险评估与应对

| 风险 | 概率 | 影响 | 应对措施 |
|------|------|------|----------|
| iOS 27 API 在旧设备不可用 | 高 | 高 | 使用 `@available` + 版本判断，保持 iOS 16 兼容 |
| Swift 6 并发检查导致编译错误 | 中 | 中 | 逐步添加 `@Sendable`、`@MainActor` 标注 |
| App Intents 审核被拒 | 低 | 高 | 确保 Intent 描述准确，不误导用户 |
| MetricKit 数据延迟投递 | 高 | 低 | 结合 OSLog 即时记录，不依赖 MetricKit 做实时监控 |

---

## 9. 验收清单

### 9.1 功能验收
- [ ] Siri 能触发 "用 StevePinyin 导入头像"
- [ ] 快捷指令 App 显示 StevePinyin 动作
- [ ] Instruments 能看到批量导入的 signpost 耗时
- [ ] 头像匹配支持拖放排序

### 9.2 性能验收
- [ ] 批量导入 100 个联系人头像以前完成
- [ ] App 启动时间无退化
- [ ] 内存占用增长 < 10%

### 9.3 质量验收
- [ ] 单元测试全部通过
- [ ] 新增代码覆盖率 > 60%
- [ ] 无新增编译警告

---

## 10. 参考资源

### 10.1 WWDC26 官方样例
- [Adopting App Intents](https://developer.apple.com/documentation/AppIntents/adopting-app-intents-to-support-system-experiences)
- [Track performance by app state using MetricKit](https://developer.apple.com/documentation/MetricKit/track-performance-by-app-state-using-metrickit)

### 10.2 本项目参考实现
- [WWDC26IntelligenceDemo](file:///Users/stevezhou/Library/Mobile%20Documents/com~apple~CloudDocs/Developer/WWDC26IntelligenceDemo) - 包含所有新功能的完整 demo

### 10.3 关键代码模板
```bash
# 在 StevePinyin 项目中参考 WWDC26IntelligenceDemo 的实现：
# - Intents/ 目录结构
# - Services/PerformanceMonitor.swift 的 signpost 用法
# - Views/ 中的 SwiftUI 交互示例
```

---

## 附录 A: 快速启动命令

```bash
# 1. 进入项目目录
cd /Users/stevezhou/Library/Mobile\ Documents/com\~apple\~CloudDocs/Developer/2026/StevePinyin

# 2. 备份当前项目
cp -r StevePinyin StevePinyin.backup.$(date +%Y%m%d)

# 3. 修改部署目标（手动或使用脚本）
# 在 Xcode 中修改，或使用 sed 替换 project.pbxproj

# 4. 创建新目录结构
mkdir -p StevePinyin/Intents
mkdir -p StevePinyin/Services/Intelligence

# 5. 验证编译
xcodebuild -project StevePinyin.xcodeproj -scheme StevePinyin -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build

# 6. 运行测试
xcodebuild test -project StevePinyin.xcodeproj -scheme StevePinyin -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0'
```

---

**下一步行动**: 请确认 Phase 1 和 Phase 2 的计划，我可立即开始生成具体实现代码。
