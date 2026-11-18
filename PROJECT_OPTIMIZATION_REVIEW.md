# StevePinyin 项目分析与优化建议

生成时间：2026-03-15

## 1. 结论速览

这个项目已经有不错的业务分层基础：`Views / ViewModels / UseCases / Services / Models` 的职责边界比很多同体量 SwiftUI 项目更清晰，核心业务逻辑也有一批单元测试在保护。当前最值得优先处理的，不是“重写”，而是把仓库卫生、超大视图拆分、状态传播方式和联系人批量写入效率这几件事收紧。

本次检查得到的几个关键基线：

| 项目 | 结果 |
| --- | --- |
| Swift 源码规模 | 约 19,456 行 |
| 测试源码规模 | 约 1,154 行 |
| 当前版本 | `MARKETING_VERSION = 3.0` |
| 最低系统版本 | `IPHONEOS_DEPLOYMENT_TARGET = 16.0` |
| Swift 语言版本 | `SWIFT_VERSION = 5.0` |
| 单元测试 | 2026-03-15 本地 `xcodebuild test` 通过 |

本次执行过的验证命令：

```bash
xcodebuild test -scheme StevePinyin -project StevePinyin.xcodeproj -destination 'platform=iOS Simulator,id=143F3FF0-3B68-4C51-89A7-0679551ED2CE' CODE_SIGNING_ALLOWED=NO
```

## 2. 项目亮点

1. 业务逻辑拆分方向是对的。
   `ContactsPinyinMaintenanceUseCase`、`PrepareAvatarMatchesUseCase`、`DeleteAvatarFlowUseCase`、`ContactAvatarImportUseCase` 等把核心流程从 View 中抽了出来，后续继续优化的空间很大。

2. 通讯录与存储层已经开始使用 actor。
   `ContactService`、`AvatarPackageService`、`StorageService`、`VCardImportService` 都在往并发安全的方向走，这比把所有读写直接塞进 ViewModel 更健康。

3. 测试重点放在 UseCase 层是正确的。
   当前测试覆盖了头像导入、删除、匹配、拼音转换、配置校验等关键业务路径，说明项目已经具备“可持续演进”的基础。

## 3. 高优先级优化建议

### P0. 先把仓库卫生收拾干净

这是我认为最该先做的一项，因为它会直接影响后续所有开发效率。

现状：

- 根目录没有看到 `.gitignore`。
- 仓库里存在 `build/`、`_ConflictBackups/`、`StevePinyin.xcodeproj/xcuserdata/` 等本地或临时产物。
- 当前工作区里也能看到大量由构建、资源导入、冲突副本带来的噪音变更。

影响：

- Git diff 信噪比变差，真实业务改动容易被淹没。
- 合并冲突概率升高。
- 新成员接手时很难判断哪些文件是项目资产，哪些只是本地产物。

建议：

1. 新增 `.gitignore`，至少忽略 `build/`、`DerivedData`、`xcuserdata`、冲突备份目录。
2. 清理已经进入仓库或工作区的构建产物与冲突副本。
3. 把资源生成物和手工素材的边界明确下来，避免再次把临时文件带进版本库。

### P1. 优先优化联系人批量写入性能

这是最可能在真实用户大通讯录上产生卡顿或耗时过长的问题。

证据：

- `StevePinyin/UseCases/ContactsPinyinMaintenanceUseCase.swift` 中的 `addPinyin`、`removePinyin`、`enableT9`、`removePinyinOnly`、`removeT9Only`、`cleanupContactsWithoutPhoneNumbers` 都是“遍历联系人 -> 每个联系人单独保存一次”。
- `StevePinyin/Services/ContactService.swift` 中 `updateContact(_:)` 每次都会新建并执行一次 `CNSaveRequest`。

影响：

- 通讯录规模一大，单次操作耗时会明显上升。
- 主流程虽然写成了 async，但底层依然是大量串行 save request，吞吐不高。
- 失败重试和中断恢复也比较难做。

建议：

1. 为批量修改增加批处理接口，例如按 50 或 100 个联系人组成一个 `CNSaveRequest` 再提交。
2. 把“可变联系人拷贝”抽成统一 helper，减少多处 `as! CNMutableContact`。
3. 为长耗时任务补充取消能力和阶段性 summary，这样用户切后台或中断时体验更稳。

### P1. 拆分超大 SwiftUI 文件，先从导入流程下手

当前有几份视图文件已经大到会显著拖慢维护效率：

| 文件 | 行数 |
| --- | ---: |
| `StevePinyin/Views/Import/ManualSelectionSheet.swift` | 1413 |
| `StevePinyin/Views/Import/AvatarPackageSelector.swift` | 1381 |
| `StevePinyin/Views/Contacts/DuplicateDetectionView.swift` | 1009 |
| `StevePinyin/Views/Settings/AboutView.swift` | 689 |
| `StevePinyin/Views/Contacts/ContactDetailView.swift` | 633 |
| `StevePinyin/Views/Contacts/ContactListView.swift` | 586 |

影响：

- 预览和编译增量变慢。
- 小改动也容易牵动大文件，review 难度高。
- 局部状态、局部动画、局部样式会越来越难复用。

建议：

1. 先拆 `Import` 功能目录，把页面级 View、Section View、Cell View、Sheet View 分层。
2. 对 `ManualSelectionSheet` 和 `AvatarPackageSelector` 先按“头部 / 筛选 / 列表 / 工具栏 / 弹窗”拆。
3. 拆分时优先保持行为不变，只做结构性整理，避免把重构和需求改动混在一起。

### P1. 把头像导入流程里的事件传播从 NotificationCenter 收拢为显式状态流

证据：

- `StevePinyin/ViewModels/ImportAvatarsViewModel+ImportFlow.swift` 和 `StevePinyin/ViewModels/ImportAvatarsViewModel+DeleteFlow.swift` 都会 `post(name: .contactAvatarsUpdated)`。
- `StevePinyin/Views/Import/ImportAvatarsView.swift` 通过 `onReceive(NotificationCenter.default.publisher(for: .contactAvatarsUpdated))` 监听刷新。
- 目前这个通知只有非常少的发送方和接收方，本质上还是单功能域内部通信。

影响：

- 状态更新链路不够直观，后续新增监听方后更容易出现“谁刷新了页面”难以追踪的问题。
- 测试时需要额外模拟系统通知，心智负担会变高。

建议：

1. 在头像导入域内优先改成显式方法调用、共享 store，或单一 ViewModel 状态回流。
2. 如果一定要保留发布订阅，建议至少收敛成域内 event enum，而不是裸 `Notification.Name`。
3. 这块改完之后，导入、删除、刷新联系人列表的行为会更容易做集成测试。

### P1. 统一图片加载策略，避免三套方案并存

证据：

- `StevePinyin/Views/Components/AvatarImage.swift` 使用 `AsyncImage`。
- `StevePinyin/Utilities/AvatarImageCache.swift` 提供了 `CachedAsyncImage` 和自定义缓存。
- `StevePinyin/Views/Components/ContactRowView.swift`、`ModernIconCell.swift`、`IconSelectionView.swift` 等又在使用 `SDWebImageSwiftUI.WebImage`。

影响：

- 不同页面的缓存策略、失败占位、过渡动画和内存行为不一致。
- 后续排查“为什么某一页加载慢 / 不命中缓存 / 图片闪烁”会变得困难。

建议：

1. 远程头像加载统一选一套方案。
   如果继续保留 `SDWebImageSwiftUI`，建议把远程图片都收敛到它。
2. 联系人本地头像可以保留单独的 `ContactAvatarImageLoader`，因为它不是标准远程图片场景。
3. 统一一个共享的占位图、失败态和裁剪样式，减少组件间视觉和行为差异。

## 4. 中优先级优化建议

### P2. 逐步替换旧导航和旧样式 API

证据：

- `StevePinyin/Views/Contacts/EditCompanyPinyinView.swift` 仍使用 `NavigationView`。
- `StevePinyin/Views/Contacts/ContactDetailView.swift` 内也有 `NavigationView`。
- 项目里仍有大量 `.foregroundColor(...)` 调用。

建议：

1. 保持新的页面优先使用 `NavigationStack`。
2. 存量页面逐步迁移，不必一次性全改。
3. 视觉样式优先迁移到 `foregroundStyle`、统一按钮样式和统一卡片样式。

这类问题不会立刻造成 bug，但会让 UI 层越来越像“多时代代码并存”，后续维护成本会上升。

### P2. 测试继续向 ViewModel 和页面关键流程补齐

当前测试方向是好的，但重心主要还在 UseCase 层。

现状：

- `StevePinyinTests` 中有较完整的 UseCase 测试。
- 暂时没看到 `ContactsPinyinViewModel`、`ImportAvatarsViewModel` 的系统化测试。
- 也没有针对关键导航/弹窗流程的 UI 或集成测试。

建议：

1. 先补 `ImportAvatarsViewModel` 的 happy path / failure path 测试。
2. 再补 `ContactsPinyinViewModel` 的权限拒绝、处理中、完成态、错误态测试。
3. 最后再考虑为导入主流程补少量 UI smoke tests，而不是一开始就大量铺 UI tests。

### P2. 清理无实际使用的第三方依赖

当前依赖解析结果里包含：

- `ConfettiSwiftUI`
- `SDWebImageSwiftUI`
- `SFSafeSymbols`
- `CustomNavigationBar`
- `CustomNavigationTitle`

其中 `CustomNavigationBar` 和 `CustomNavigationTitle` 本次检索没有发现实际 import。

建议：

1. 确认这两个包是否已经不再使用。
2. 如果确实没用，尽快从工程依赖里移除。

收益：

- 减少包解析和构建时间。
- 降低后续升级 Xcode 或 SPM 时的兼容性噪音。

### P2. 把日志与延时任务改成更现代的写法

证据：

- 项目里存在多处 `print(...)`。
- 多个文件仍在使用 `DispatchQueue.main.asyncAfter(...)` 做 UI 延时或 debounce。

建议：

1. 把运行时日志逐步迁移到 `Logger`。
2. 把可取消的延时逻辑改成 `Task.sleep` + `Task.cancel()`。
3. 对用户可见的动画延时和搜索防抖，统一封装一套工具，不要每个页面各写一份。

### P2. 为 Swift 6 做准备，但不要一次性硬切

当前工程还是 `SWIFT_VERSION = 5.0`，最低版本是 iOS 16。

我的建议不是立刻全量切到 Swift 6 严格模式，而是分两步走：

1. 先打开更多并发警告和编译告警，清理明显问题。
2. 等 iOS 16 支持策略确认后，再决定是否提升最低版本并引入更现代的 Observation 方案。

如果短期内必须继续支持 iOS 16，就不建议为了“追新”而强行全量迁移到 `@Observable`。

## 5. 建议执行顺序

### 第一阶段：1 到 2 天内可以完成

| 优先级 | 任务 |
| --- | --- |
| P0 | 新增 `.gitignore` 并清理 `build/`、`xcuserdata/`、`_ConflictBackups/` |
| P1 | 移除未使用的 SPM 依赖 |
| P1 | 把 `print` 和零散延时逻辑开始收口 |

### 第二阶段：3 到 5 天内可以完成

| 优先级 | 任务 |
| --- | --- |
| P1 | 统一远程图片加载方案 |
| P1 | 收敛头像导入功能中的 `NotificationCenter` 事件流 |
| P1 | 拆分 `AvatarPackageSelector` 与 `ManualSelectionSheet` |

### 第三阶段：需要单独开分支推进

| 优先级 | 任务 |
| --- | --- |
| P1 | 优化联系人批量写入策略 |
| P2 | 为 `ImportAvatarsViewModel` 与 `ContactsPinyinViewModel` 增加测试 |
| P2 | 逐步迁移旧导航与旧样式 API |
| P2 | 评估 Swift 6 / 更现代 Observation 的迁移路径 |

## 6. 我最推荐你先做的三件事

如果只做最有性价比的三项，我建议顺序如下：

1. 仓库卫生治理。
2. 拆分导入流程的超大视图文件。
3. 优化联系人批量写入路径。

这三项做完之后，项目的可维护性、协作体验和大数据量下的用户体验都会明显提升。

