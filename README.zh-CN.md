# StevePinyin

[![CI](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ci.yml/badge.svg?branch=ios27-upgrade)](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ci.yml)
[![IPA Release](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ipa-release.yml/badge.svg?branch=ios27-upgrade)](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ipa-release.yml)

[English](README.md) · **简体中文**

iOS 联系人拼音与头像工具箱。为中文联系人补齐姓名 / 公司拼音（多音字识别），生成 T9 拨号索引，检测并合并重复联系人，批量导入匹配头像——内置 vCard 与中国黄页导入。

> **分支说明** — `ios27-upgrade` 为本仓库的 iOS App 源码；`main` 是头像包数据源仓库（App 内可下载的 vCard / 头像 JSON 数据）。两个分支独立维护。

## 功能

| 功能 | 说明 |
|---|---|
| 拼音注音 | 多音字姓氏与机构名精准注音，支持带声调、全拼、首字母多种格式 |
| T9 拨号索引 | 生成拨号键盘拼音缩写，便于在电话 App 中快速检索 |
| 重复检测 | 按姓名、电话、邮箱、拼音多维合并清理重复联系人 |
| 头像导入 | 统一 / 按序 / 手动三种匹配模式，支持 URL 头像包；Apple Intelligence 视觉质检与语义推荐，模型不可用时自动回退本地引擎 |
| vCard 与黄页 | 本地 `.vcf` 文件、URL 订阅，中国常用客服号码一键导入 |
| Siri 与快捷指令 | 批量加拼音、生成 T9、查重复、导入头像均可语音 / 快捷指令触发，支持应用内搜索 |
| 性能观测 | MetricKit + OSLog signpost 全链路打点，内置 App 内诊断看板 |

## 下载安装

每次推送都会自动打包 IPA 并发布到 [Releases](https://github.com/zxfccmm4/StevePinyin/releases)。

IPA 为**未签名**版本（CI 无证书），安装方式任选：

- **TrollStore** — 直接安装
- **Sideloadly / AltStore** — 用你自己的 Apple ID 重签后安装

## 环境要求

- iOS 27.0+
- Xcode 27.1

## 构建与测试

```bash
# 构建
xcodebuild -project StevePinyin.xcodeproj -scheme StevePinyin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 测试套件（68 个测试 / 20 个套件）
xcodebuild test -project StevePinyin.xcodeproj -scheme StevePinyin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:StevePinyinTests
```

也可以直接用 Xcode 打开工程，按 ⌘R 运行。

push 与 PR 会自动触发 GitHub Actions CI（[ci.yml](.github/workflows/ci.yml)）；push 还会自动打包并发布 IPA（[ipa-release.yml](.github/workflows/ipa-release.yml)）。

## 技术要点

- **SwiftUI + Liquid Glass** — 统一设计系统：`glassEffect`、`GlassEffectContainer`、`.glassProminent`
- **FoundationModels** — `LanguageModelSession.DynamicProfile` + `@Generable` 结构化输出
- **联系人批量化写入** — 200 条 / 批 `CNSaveRequest`，80 ms 进度节流，批写失败逐条回退
- **图片管线** — `CGImageSource` 降采样、`NSCache` 缓存、单飞合并
- **本地化** — 简体中文、繁体中文（台湾 / 香港）、英语、日语、韩语
- **依赖** — [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI)（SwiftPM）

## 联系

- Twitter：[@st7evechou](https://twitter.com/st7evechou)
- Telegram：[t.me/st7evee](https://t.me/st7evee)
- 头像包数据：`main` 分支 / [vCards CN](https://github.com/metowolf/vCards)
