import SwiftUI

struct ImportAvatarSheetViews: ViewModifier {
    @Bindable var viewModel: ImportAvatarsViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showingPackageSelector) {
                AvatarPackageSelector(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingPackageDetail) {
                if let package = viewModel.currentPackage {
                    PackageDetailView(
                        package: package,
                        selectedIcons: .constant([:])
                    )
                }
            }
            .sheet(isPresented: $viewModel.showingMatchPreview) {
                MatchPreviewView(
                    matches: viewModel.matchedContacts,
                    availableIcons: viewModel.matchPreviewIcons
                ) { matches in
                    viewModel.prepareImportConfirmation(matches: matches)
                }
            }
            .sheet(item: $viewModel.importConfirmationState) { state in
                ImportConfirmationSheet(state: state, viewModel: viewModel)
            }
    }
}

extension View {
    func importAvatarSheets(viewModel: ImportAvatarsViewModel) -> some View {
        modifier(ImportAvatarSheetViews(viewModel: viewModel))
    }
}
