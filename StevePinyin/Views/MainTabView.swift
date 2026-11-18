import SwiftUI

struct MainTabView: View {
    @AppStorage("lastVersionPrompt") private var lastVersionPrompt: String = ""
    @State private var showWhatsNew = false
    @Binding var selectedTab: Int
    @State private var showingDuplicateDetectionFromIntent = false
    @State private var intentRouter = IntentRouter.shared
    @State private var batchCoordinator = BatchTaskCoordinator.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab_contacts"), systemImage: "person.text.rectangle", value: 0) {
                ContentView()
            }

            Tab(String(localized: "tab_import_avatars"), systemImage: "person.crop.artframe", value: 1) {
                ImportAvatarsView()
            }

            Tab(String(localized: "tab_about"), systemImage: "slider.horizontal.3", value: 2) {
                NavigationStack {
                    AboutView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultTabBarPlacement(.tabBar)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: batchCoordinator.activeTask != nil) {
            if let task = batchCoordinator.activeTask {
                BatchProgressAccessoryBar(
                    task: task,
                    canCancel: batchCoordinator.canCancelActiveTask,
                    onCancel: { batchCoordinator.cancelActiveTask() }
                )
            }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView()
        }
        .fullScreenCover(isPresented: $showingDuplicateDetectionFromIntent) {
            NavigationStack {
                DuplicateDetectionView(showsDismissButton: true)
            }
        }
        .task {
            if let target = intentRouter.navigationTarget {
                await Task.yield()
                handleNavigation(target: target)
            } else {
                checkAndShowWhatsNew()
            }
        }
        .onChange(of: intentRouter.navigationTarget) { _, target in
            if let target {
                handleNavigation(target: target)
            }
        }
    }

    private func handleNavigation(target: NavigationTarget) {
        switch target {
        case .importAvatars:
            selectedTab = 1
            PerformanceMonitor.shared.record(
                title: "IntentNavigation",
                detail: "切换至头像导入工作台"
            )

        case .matchResults:
            selectedTab = 1
            PerformanceMonitor.shared.record(
                title: "IntentNavigation",
                detail: "切换至头像匹配结果"
            )

        case .duplicateContacts(let duplicates):
            selectedTab = 0
            if showWhatsNew {
                showWhatsNew = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showingDuplicateDetectionFromIntent = true
                }
            } else {
                Task { @MainActor in
                    await Task.yield()
                    showingDuplicateDetectionFromIntent = true
                }
            }
            PerformanceMonitor.shared.record(
                title: "IntentNavigation",
                detail: "显示重复联系人: \(duplicates.count) 组"
            )

        case .searchContacts(let query):
            selectedTab = 0
            PerformanceMonitor.shared.record(
                title: "IntentNavigation",
                detail: "应用内搜索联系人: \(query)"
            )

        case .settings:
            selectedTab = 2
            PerformanceMonitor.shared.record(
                title: "IntentNavigation",
                detail: "切换至设置与关于"
            )
        }

        intentRouter.clearNavigation()
    }

    private func checkAndShowWhatsNew() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        if !currentVersion.isEmpty, lastVersionPrompt != currentVersion {
            lastVersionPrompt = currentVersion
            showWhatsNew = true
        }
    }
}

extension MainTabView {
    init() {
        self._selectedTab = .constant(0)
    }
}

private struct BatchProgressAccessoryBar: View {
    let task: ActiveBatchTask
    let canCancel: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: task.fractionCompleted)
                .progressViewStyle(.circular)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .lineLimit(1)

                    if task.totalCount > 0 {
                        Text(task.percentageText)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                if !task.subtitle.isEmpty {
                    Text(rateFormattedSubtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if canCancel {
                Button(NSLocalizedString("Cancel", comment: ""), action: onCancel)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var rateFormattedSubtitle: String {
        if task.itemsPerSecond >= 1 {
            return "\(task.subtitle) · \(Int(task.itemsPerSecond.rounded()))/s"
        }
        return task.subtitle
    }
}

#Preview {
    MainTabView()
}
