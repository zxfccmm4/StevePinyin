import Foundation

struct ValidateAvatarImportConfigurationUseCase {
    func validate(
        importMode: AvatarImportMode,
        selectedPackage: IconPackage?,
        selectedUniformIcon: Icon?
    ) -> String? {
        switch importMode {
        case .single:
            if selectedUniformIcon == nil {
                return NSLocalizedString("Please select an avatar first", comment: "")
            }
        case .sequential, .manual:
            if selectedPackage == nil {
                return NSLocalizedString("Please select at least one avatar package", comment: "")
            }
        }

        return nil
    }
}
