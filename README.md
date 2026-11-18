# StevePinyin

[![CI](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ci.yml/badge.svg?branch=ios27-upgrade)](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ci.yml)

联系人拼音与头像工具箱。为中文联系人补齐姓名/公司拼音（多音字识别）、生成 T9 拨号索引、检测合并重复联系人、批量导入匹配头像，并支持 vCard 与中国黄页导入。

**本分支（`ios27-upgrade`）为 iOS App 源码**；`main` 分支为头像包数据源仓库（App 内可下载的 vCard / 头像 JSON 数据），两者独立维护。

## 功能

- **拼音注音** — 多音字姓氏与机构名精准注音，带声调 / 全拼 / 首字母多种格式
- **T9 拨号搜索** — 生成拨号键盘拼音缩写，强化电话 App 快速检索
- **重复检测** — 按姓名 / 电话 / 邮箱 / 拼音多维合并清理重复联系人
- **头像导入** — 统一 / 按序 / 手动三种匹配模式，URL 头像包导入，Apple Intelligence 视觉质检与语义推荐（模型不可用时自动回退本地引擎）
- **vCard 与黄页** — 本地 .vcf 文件、URL 订阅、中国常用客服号码一键导入
- **Siri 与快捷指令** — 批量加拼音、开 T9、查重复、导入头像均可语音/快捷指令触发，支持应用内搜索
- **性能观测** — MetricKit + OSLog signpost 全链路打点，App 内诊断看板

## 技术要点

- iOS 27.0 部署目标，Xcode 27.1 构建
- SwiftUI + Liquid Glass（`GlassDesignSystem` 统一设计系统：`glassEffect` / `GlassEffectContainer` / `.glassProminent`）
- FoundationModels（`LanguageModelSession.DynamicProfile` + `@Generable` 结构化输出）
- 联系人写入批量化：200/批 `CNSaveRequest`、80ms 进度节流、批写失败逐条回退
- 图片管线：CGImageSource 降采样 + NSCache 缓存 + 单飞合并
- 依赖：[ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI)（SPM）
- 本地化：简体中文、繁体中文（台湾/香港）、英语、日语、韩语

## 构建与测试

```bash
# 打开 Xcode 直接 Cmd+R，或命令行：
xcodebuild -project StevePinyin.xcodeproj -scheme StevePinyin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 运行测试套件（68 tests / 20 suites）
xcodebuild test -project StevePinyin.xcodeproj -scheme StevePinyin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:StevePinyinTests
```

推送与 PR 自动触发 GitHub Actions CI（`.github/workflows/ci.yml`）。

## 联系

- Twitter：[@st7evechou](https://twitter.com/st7evechou)
- Telegram：[t.me/st7evee](https://t.me/st7evee)
- 头像包数据仓库：`main` 分支 / [vCards CN](https://github.com/metowolf/vCards)
