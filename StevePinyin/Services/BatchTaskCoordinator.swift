import Foundation
import Observation

struct ActiveBatchTask: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var subtitle: String
    var processedCount: Int
    var totalCount: Int
    var itemsPerSecond: Double
    var isCancelling: Bool

    var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        return min(max(Double(processedCount) / Double(totalCount), 0), 1)
    }

    var percentageText: String {
        "\(Int((fractionCompleted * 100).rounded()))%"
    }
}

@Observable
@MainActor
final class BatchTaskCoordinator {
    static let shared = BatchTaskCoordinator()

    private(set) var activeTask: ActiveBatchTask?
    private var startedAt: ContinuousClock.Instant?
    private var cancelHandler: (() -> Void)?

    init() {}

    @discardableResult
    func beginTask(
        title: String,
        subtitle: String = "",
        totalCount: Int = 0,
        onCancel: (() -> Void)? = nil
    ) -> UUID {
        let taskID = UUID()
        startedAt = ContinuousClock.now
        cancelHandler = onCancel
        activeTask = ActiveBatchTask(
            id: taskID,
            title: title,
            subtitle: subtitle,
            processedCount: 0,
            totalCount: max(totalCount, 0),
            itemsPerSecond: 0,
            isCancelling: false
        )
        return taskID
    }

    func updateTask(
        id: UUID,
        processedCount: Int,
        totalCount: Int,
        subtitle: String? = nil
    ) {
        guard var current = activeTask, current.id == id else { return }

        current.processedCount = max(processedCount, 0)
        current.totalCount = max(totalCount, 0)
        if let subtitle {
            current.subtitle = subtitle
        }

        if let startedAt, processedCount > 0 {
            let elapsed = startedAt.duration(to: ContinuousClock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            if seconds > 0.05 {
                current.itemsPerSecond = Double(processedCount) / seconds
            }
        }

        activeTask = current
    }

    func finishTask(id: UUID) {
        guard activeTask?.id == id else { return }
        activeTask = nil
        startedAt = nil
        cancelHandler = nil
    }

    func cancelActiveTask() {
        guard var current = activeTask, current.isCancelling == false else { return }
        current.isCancelling = true
        current.subtitle = NSLocalizedString("Cancelling...", comment: "")
        activeTask = current
        cancelHandler?()
    }

    var canCancelActiveTask: Bool {
        activeTask != nil && cancelHandler != nil && activeTask?.isCancelling == false
    }
}
