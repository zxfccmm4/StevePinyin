//
//  StevePinyinApp.swift
//  StevePinyin
//
//  Updated for WWDC26 - App Intents & MetricKit 支持
//

import SwiftUI
import MetricKit
import os

@main
struct StevePinyinApp: App {
    @AppStorage("selectedTabIndex") private var selectedTab: Int = 0
    @State private var performanceMonitor = PerformanceMonitor.shared
    private let logger = Logger(subsystem: "com.stevezhou.StevePinyin", category: "App")

    var body: some Scene {
        WindowGroup {
            MainTabView(selectedTab: $selectedTab)
                .asyncImageURLSession(AvatarNetworkConfiguration.session)
                .task {
                    performanceMonitor.startMonitoring()
                    performanceMonitor.record(
                        title: "AppLaunch",
                        detail: "StevePinyin iOS 27 工作台启动完成"
                    )
                    logger.info("StevePinyin launched with iOS 26/27 features")
                }
        }
    }
}
