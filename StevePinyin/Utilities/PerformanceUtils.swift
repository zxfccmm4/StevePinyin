import Foundation

struct ProgressThrottler: Sendable {
    private let interval: Duration
    private var lastEmittedAt: ContinuousClock.Instant?

    init(interval: Duration = .milliseconds(80)) {
        self.interval = interval
    }

    mutating func shouldEmit(force: Bool = false) -> Bool {
        let now = ContinuousClock.now
        if force {
            lastEmittedAt = now
            return true
        }
        guard let lastEmittedAt else {
            self.lastEmittedAt = now
            return true
        }
        if lastEmittedAt.duration(to: now) >= interval {
            self.lastEmittedAt = now
            return true
        }
        return false
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, isEmpty == false else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
