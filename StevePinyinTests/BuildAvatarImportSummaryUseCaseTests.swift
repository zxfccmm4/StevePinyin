import Foundation
import Testing
@testable import StevePinyin

struct BuildAvatarImportSummaryUseCaseTests {
    private let sut = BuildAvatarImportSummaryUseCase()

    @Test("Summary message includes success and failure counts")
    func summaryIncludesCounts() {
        let result = AvatarImportResult(successCount: 2, failureCount: 1, errors: [])
        let message = sut.execute(result: result)
        let expected = String(
            format: NSLocalizedString("Import complete\nSuccess: %d\nFailed: %d", comment: ""),
            result.successCount,
            result.failureCount
        )

        #expect(message == expected)
    }
}
