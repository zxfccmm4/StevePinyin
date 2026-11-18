//
//  StevePinyinShortcuts.swift
//  StevePinyin
//
//  App Shortcuts 注册 - 快捷指令入口
//

import AppIntents

struct StevePinyinShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .blue }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddContactsPinyinIntent(),
            phrases: [
                "用 \(.applicationName) 添加通讯录拼音",
                "用 \(.applicationName) 生成联系人拼音",
            ],
            shortTitle: "添加拼音",
            systemImageName: "wand.and.rays"
        )

        AppShortcut(
            intent: EnableT9SearchIntent(),
            phrases: [
                "用 \(.applicationName) 开启 T9 搜索",
                "用 \(.applicationName) 开启拨号搜索",
            ],
            shortTitle: "开启 T9 搜索",
            systemImageName: "keyboard.badge.eye"
        )

        AppShortcut(
            intent: CheckDuplicateContactsIntent(scope: .balanced),
            phrases: [
                "用 \(.applicationName) 检查重复联系人",
            ],
            shortTitle: "检查重复",
            systemImageName: "person.2.badge.minus"
        )

        AppShortcut(
            intent: ImportAvatarsIntent(mode: .sequential),
            phrases: [
                "用 \(.applicationName) 导入头像",
            ],
            shortTitle: "导入头像",
            systemImageName: "person.crop.circle.badge.plus"
        )

        AppShortcut(
            intent: MatchAvatarsIntent(),
            phrases: [
                "用 \(.applicationName) 匹配头像",
            ],
            shortTitle: "匹配头像",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
