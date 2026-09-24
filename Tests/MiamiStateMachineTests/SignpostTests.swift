import Foundation
import Testing
import MiamiStateMachine

/// How many times states and events have been described. The count is protected
/// by a lock, as nothing says which threads a state machine describes them on.
private final class DescriptionCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }
}

/// Counts every time a state or an event is described.
private let descriptions = DescriptionCount()

/// A state counting how many times it is described.
private enum DescribedState: Hashable, Sendable, CustomStringConvertible {
    case off, on

    var description: String {
        descriptions.increment()
        return self == .off ? "off" : "on"
    }
}

/// An event counting how many times it is described.
private enum DescribedEvent: StateMachineEvent, CustomStringConvertible {
    case toggle, jam

    var description: String {
        descriptions.increment()
        return self == .toggle ? "toggle" : "jam"
    }
}

/// The signposts cannot be read back by a test, as they are only written
/// while Instruments records them. What can be tested is what they cost.
struct SignpostTests {

    /// Signposts written all the time would describe every state entered and
    /// every trigger, which made processing an event five times slower.
    @Test func nothingIsDescribedWhenNothingRecords() async throws {
        let stateMachine = try StateMachine(transitions: [
            TransitionRule(from: DescribedState.off, event: DescribedEvent.toggle, to: .on),
            TransitionRule(from: .on, event: .toggle, to: .off),
        ], initialState: .off)
        let before = descriptions.value

        for _ in 0 ..< 10 {
            await stateMachine.process(.toggle)
            await stateMachine.process(.jam)
        }

        #expect(await stateMachine.stateChangeCount == 10)
        #expect(await stateMachine.rejectedEventsCount == 10)
        #expect(descriptions.value == before)
    }
}
