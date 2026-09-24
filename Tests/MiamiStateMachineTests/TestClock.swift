import Foundation

/// A clock whose time only moves when a test moves it, so a test of something
/// timed neither waits for the time nor depends on how fast it runs. It is
/// protected by a lock, as nothing says which threads sleep on it.
final class TestClock: Clock, @unchecked Sendable {

    /// A point in the time of the clock, as the time since it started.
    struct Instant: InstantProtocol {
        let offset: Swift.Duration

        func advanced(by duration: Swift.Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Swift.Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    /// A task sleeping until a point in time.
    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [UUID: Sleeper] = [:]

    var now: Instant {
        lock.withLock { current }
    }

    var minimumResolution: Swift.Duration {
        .zero
    }

    /// Number of tasks sleeping on the clock.
    var sleeperCount: Int {
        lock.withLock { sleepers.count }
    }

    func sleep(until deadline: Instant, tolerance: Swift.Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                lock.lock()
                guard deadline > current else {
                    lock.unlock()
                    continuation.resume()
                    return
                }
                // A task cancelled before it got here is not woken by the handler.
                guard !Task.isCancelled else {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                lock.unlock()
            }
        } onCancel: {
            let sleeper = lock.withLock { sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the time forward, and wakes the tasks sleeping until then.
    /// - Parameter duration: How much time passes.
    func advance(by duration: Swift.Duration) {
        let woken = lock.withLock {
            current = current.advanced(by: duration)
            let due = sleepers.filter { $0.value.deadline <= current }
            for id in due.keys {
                sleepers[id] = nil
            }
            return Array(due.values)
        }
        for sleeper in woken {
            sleeper.continuation.resume()
        }
    }
}
