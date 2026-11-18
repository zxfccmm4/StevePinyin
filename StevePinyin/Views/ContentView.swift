import ConfettiSwiftUI
import Contacts
import SwiftUI
import UIKit

private enum ContactsRoute: Hashable {
    case addPinyin
    case t9Search
    case processedList
    case importedVCards
    case cleanup
}

struct ContentView: View {
    @State private var viewModel = ContactsPinyinViewModel()
    @State private var vCardViewModel = ImportVCardViewModel()
    @State private var intentRouter = IntentRouter.shared
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 18) {
                        if viewModel.isProcessing {
                            ContactsProcessingView(
                                processedCount: viewModel.processedCount,
                                totalCount: viewModel.totalCount
                            )
                        } else {
                            workbenchHeaderCard
                            coreActionsSection
                            vCardQuickSection
                            maintenanceSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .background(AmbientGlassBackdrop())
            .navigationTitle(String(localized: "Contacts Pinyin"))
            .navigationDestination(for: ContactsRoute.self) { route in
                destinationView(for: route)
            }
        }
        .onAppear {
            viewModel.onAppear()
            consumePendingSearchIfNeeded()
        }
        .onChange(of: intentRouter.pendingContactSearchQuery) { _, _ in
            consumePendingSearchIfNeeded()
        }
        .confettiCannon(
            counter: $viewModel.counter,
            num: 80,
            openingAngle: Angle(degrees: 0),
            closingAngle: Angle(degrees: 360),
            radius: 200
        )
        .alert(String(localized: "Result"), isPresented: $viewModel.showAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert(NSLocalizedString("Import Result", comment: ""), isPresented: $vCardViewModel.showAlert) {
            if !vCardViewModel.importedContacts.isEmpty {
                Button(NSLocalizedString("Imported Contacts", comment: "")) {
                    navigationPath.append(ContactsRoute.importedVCards)
                }
            }
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(vCardViewModel.alertMessage)
        }
        .confirmationDialog(
            String(localized: "China Yellow Pages"),
            isPresented: $vCardViewModel.showChinaYellowPagesConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("Import", comment: "")) {
                Task { await vCardViewModel.importChinaYellowPages() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("将下载并导入常用中国公共服务黄页号码到“StevePinyin vCards”分组。")
        }
        .sheet(isPresented: $vCardViewModel.isFilePickerPresented) {
            DocumentPicker { url in
                Task { await vCardViewModel.importVCardFile(from: url) }
            }
        }
        .alert(
            NSLocalizedString("Import from URL", comment: ""),
            isPresented: $vCardViewModel.showURLInputAlert
        ) {
            TextField(NSLocalizedString("Enter vCards URL", comment: ""), text: $vCardViewModel.urlString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(NSLocalizedString("Import", comment: "")) {
                Task { await vCardViewModel.importFromEnteredURL() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .alert(
            viewModel.pendingCleanupAction?.confirmTitle ?? "",
            isPresented: $viewModel.showCleanupConfirmation
        ) {
            Button(viewModel.pendingCleanupAction?.confirmButtonTitle ?? "", role: .destructive) {
                viewModel.executeCleanupAction()
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                viewModel.pendingCleanupAction = nil
            }
        } message: {
            Text(viewModel.pendingCleanupAction?.confirmMessage ?? "")
        }
        .fullScreenCover(isPresented: $viewModel.showDuplicateDetection) {
            NavigationStack {
                DuplicateDetectionView(showsDismissButton: true)
            }
        }
    }

    private var workbenchHeaderCard: some View {
        GlassSectionCard(cornerRadius: 26, tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("通讯录拼音与拨号工作台")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Text("一键补齐多音字姓名与公司拼音、生成 T9 索引并清理重复项")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.processedContacts.isEmpty {
                    Button {
                        navigationPath.append(ContactsRoute.processedList)
                    } label: {
                        HStack {
                            Label(
                                String(format: NSLocalizedString("Successfully processed %d contacts", comment: ""), viewModel.processedContacts.count),
                                systemImage: "checkmark.seal.fill"
                            )
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Spacer()
                            Text("查看与校对")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                }
            }
        }
    }

    private var coreActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    GlassActionTile(
                        title: String(localized: "Add Pinyin"),
                        subtitle: "多音字姓氏与机构精准注音",
                        systemImage: "wand.and.rays",
                        tint: .blue
                    ) {
                        HapticManager.medium()
                        navigationPath.append(ContactsRoute.addPinyin)
                    }

                    GlassActionTile(
                        title: String(localized: "T9 Search"),
                        subtitle: "拨号键盘首字母快速检索",
                        systemImage: "keyboard",
                        tint: .green
                    ) {
                        HapticManager.medium()
                        navigationPath.append(ContactsRoute.t9Search)
                    }
                }
            }

            GlassSectionCard(cornerRadius: 22, padding: 14, tint: .orange) {
                GlassRowButton(
                    title: String(localized: "Duplicate Detection"),
                    subtitle: "按姓名、电话、邮箱、拼音多维合并清理重复项",
                    systemImage: "person.2.badge.gearshape",
                    tint: .orange
                ) {
                    HapticManager.medium()
                    viewModel.showDuplicateSheet()
                }
            }
        }
    }

    private var vCardQuickSection: some View {
        GlassSectionCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(NSLocalizedString("Import vCards", comment: ""))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                    if vCardViewModel.isImporting || vCardViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if !vCardViewModel.importedContacts.isEmpty {
                        Button("\(vCardViewModel.importedContacts.count) 位已导入") {
                            navigationPath.append(ContactsRoute.importedVCards)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glass)
                    }
                }

                GlassRowButton(
                    title: String(localized: "China Yellow Pages"),
                    subtitle: "一键导入常用客服、快递与公共服务号码",
                    systemImage: "phone.circle.fill",
                    tint: .orange
                ) {
                    HapticManager.medium()
                    vCardViewModel.presentChinaYellowPagesConfirmation()
                }

                Divider()

                GlassRowButton(
                    title: String(localized: "From File"),
                    subtitle: "直接选择本地 .vcf 通讯录文件导入",
                    systemImage: "doc.circle.fill",
                    tint: .purple
                ) {
                    HapticManager.medium()
                    vCardViewModel.presentFilePicker()
                }

                Divider()

                GlassRowButton(
                    title: String(localized: "From URL"),
                    subtitle: "输入远程 vCard 订阅或文件地址直接导入",
                    systemImage: "link.circle.fill",
                    tint: .cyan
                ) {
                    HapticManager.medium()
                    vCardViewModel.presentURLInput()
                }
            }
        }
    }

    private var maintenanceSection: some View {
        GlassSectionCard(cornerRadius: 22, padding: 14, tint: .red) {
            GlassRowButton(
                title: String(localized: "Cleanup"),
                subtitle: "单独清除拼音、T9 数据、无号码联系人或黄页分组",
                systemImage: "trash.circle.fill",
                tint: .red
            ) {
                HapticManager.rigid()
                navigationPath.append(ContactsRoute.cleanup)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: ContactsRoute) -> some View {
        switch route {
        case .addPinyin:
            ContactsPinyinFormatSelectionSheet(handleSelection: viewModel.handleSelection(format:))
        case .t9Search:
            ContactsT9FormatSelectionSheet(handleT9Selection: viewModel.handleT9Selection(_:))
        case .processedList:
            ContactListView(
                processedContacts: $viewModel.processedContacts,
                searchText: $viewModel.searchText
            )
        case .importedVCards:
            ImportVCardView(viewModel: vCardViewModel)
        case .cleanup:
            CleanupSheet { action in
                viewModel.requestCleanupConfirmation(action)
            }
        }
    }

    private func consumePendingSearchIfNeeded() {
        guard let query = intentRouter.consumePendingSearchQuery() else { return }
        viewModel.searchText = query
        navigationPath.append(ContactsRoute.processedList)
    }
}

#Preview {
    ContentView()
}
