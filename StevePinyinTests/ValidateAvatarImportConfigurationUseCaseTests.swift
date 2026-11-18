import Foundation
import Testing
@testable import StevePinyin

struct ValidateAvatarImportConfigurationUseCaseTests {
    private let sut = ValidateAvatarImportConfigurationUseCase()

    @Test("Single mode requires a selected avatar")
    func singleModeRequiresSelectedAvatar() {
        let message = sut.validate(
            importMode: .single,
            selectedPackage: nil,
            selectedUniformIcon: nil
        )

        #expect(message == NSLocalizedString("Please select an avatar first", comment: ""))
    }

    @Test("Package-based modes require a package", arguments: [AvatarImportMode.sequential, .manual])
    func packageModesRequirePackage(mode: AvatarImportMode) {
        let message = sut.validate(
            importMode: mode,
            selectedPackage: nil,
            selectedUniformIcon: nil
        )

        #expect(message == NSLocalizedString("Please select at least one avatar package", comment: ""))
    }

    @Test("Valid configurations pass without a message")
    func validConfigurationsPass() {
        let icon = Icon(name: "star", url: "system:star.fill")
        let package = IconPackage(name: "Pkg", description: "Desc", icons: [icon])

        #expect(
            sut.validate(
                importMode: .single,
                selectedPackage: nil,
                selectedUniformIcon: icon
            ) == nil
        )
        #expect(
            sut.validate(
                importMode: .sequential,
                selectedPackage: package,
                selectedUniformIcon: nil
            ) == nil
        )
    }
}
