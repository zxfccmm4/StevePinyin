# StevePinyin

[![CI](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ci.yml/badge.svg?branch=ios27-upgrade)](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ci.yml)
[![IPA Release](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ipa-release.yml/badge.svg?branch=ios27-upgrade)](https://github.com/zxfccmm4/StevePinyin/actions/workflows/ipa-release.yml)

**English** · [简体中文](README.zh-CN.md)

Contacts pinyin & avatar toolbox for iOS. It annotates Chinese contact names and company names with pinyin (heteronym-aware), generates T9 dialing indices, detects and merges duplicate contacts, and batch-imports contact avatars — with vCard and China yellow-page import built in.

> **Branch note** — `ios27-upgrade` hosts the iOS app source. `main` is the avatar-package data repository consumed by the app at runtime (vCard / avatar JSON packages). The two branches are maintained independently.

## Features

| Feature | Description |
|---|---|
| Pinyin annotation | Heteronym-aware pinyin for surnames and company names, in toned, plain, or initials format |
| T9 dialing index | Pinyin initials for the dialer keyboard, so contacts can be found from the Phone app |
| Duplicate detection | Merge and clean duplicates by name, phone, email, and pinyin |
| Avatar import | Uniform, sequential, and manual matching modes; URL avatar packages; Apple Intelligence visual QC and semantic recommendations with automatic local fallback |
| vCard & yellow pages | Local `.vcf` files, URL subscriptions, and one-tap import of common China support numbers |
| Siri & Shortcuts | Annotate pinyin, build T9, detect duplicates, import avatars — all via voice or Shortcuts, with in-app search |
| Performance observability | MetricKit + OSLog signposts end to end, with an in-app diagnostics dashboard |

## Download & Install

Every push to this repository builds an IPA automatically — grab it from [Releases](https://github.com/zxfccmm4/StevePinyin/releases).

The IPA is **unsigned** (no signing certificate on CI). Install it with one of:

- **TrollStore** — install directly
- **Sideloadly / AltStore** — re-sign with your own Apple ID, then install

## Requirements

- iOS 27.0+
- Xcode 27.1

## Build & Test

```bash
# Build
xcodebuild -project StevePinyin.xcodeproj -scheme StevePinyin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Test suite (68 tests / 20 suites)
xcodebuild test -project StevePinyin.xcodeproj -scheme StevePinyin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:StevePinyinTests
```

Or just open the project in Xcode and hit ⌘R.

Pushes and pull requests run GitHub Actions CI ([ci.yml](.github/workflows/ci.yml)); pushes additionally build and publish an IPA ([ipa-release.yml](.github/workflows/ipa-release.yml)).

## Tech Highlights

- **SwiftUI + Liquid Glass** — unified design system: `glassEffect`, `GlassEffectContainer`, `.glassProminent`
- **FoundationModels** — `LanguageModelSession.DynamicProfile` with `@Generable` structured output
- **Contacts batching** — 200-contact `CNSaveRequest` batches, 80 ms progress throttling, per-item fallback when a batch fails
- **Image pipeline** — `CGImageSource` downsampling, `NSCache`, single-flight merging
- **Localization** — Simplified Chinese, Traditional Chinese (Taiwan / Hong Kong), English, Japanese, Korean
- **Dependency** — [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI) via SwiftPM

## Contact

- Twitter: [@st7evechou](https://twitter.com/st7evechou)
- Telegram: [t.me/st7evee](https://t.me/st7evee)
- Avatar package data: `main` branch / [vCards CN](https://github.com/metowolf/vCards)
