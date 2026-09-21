import Foundation
import Testing
import MiamiStateMachine
import MiamiDiagrams

/// How many times states have been compared. The count is protected by
/// a lock, as nothing says which threads a state machine compares states on.
private final class ComparisonCount: @unchecked Sendable {
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

/// A state counting how many times states are compared. The count tells how
/// much work is done to make a diagram, without measuring time.
private struct CountedState: Hashable, Sendable {
    let number: Int
    let comparisons: ComparisonCount

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.comparisons.increment()
        return lhs.number == rhs.number
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

/// The work done to make a diagram should grow with the number of
/// transitions, and not with the number of transitions times itself,
/// for diagrams of generated definitions to be usable.
struct LargeDiagramTests {
    private let stateCount = 2_000
    private let comparisons = ComparisonCount()

    private func state(_ number: Int) -> CountedState {
        CountedState(number: number % stateCount, comparisons: comparisons)
    }

    /// A ring of states, where the event 0 leads from every state to the next one.
    private func makeRing() -> Set<StateTransition<Int, CountedState>> {
        Set((0 ..< stateCount).map { number in
            StateTransition(from: state(number), event: 0, to: state(number + 1))
        })
    }

    @Test func diagramsDoNotSearchAllTransitionsForEveryState() throws {
        let stateMachine = try StateMachine(transitions: makeRing(), initialState: state(0))
        let comparisonsBefore = comparisons.value

        let diagrams = [stateMachine.dotDiagram, stateMachine.mermaidDiagram]

        // An arrow for every transition, and the one to the initial state.
        for diagram in diagrams {
            #expect(diagram.split(separator: "\n").filter { $0.contains("->") }.count == stateCount + 1)
        }

        // Looking for the transitions between every two states is 4 000 000
        // searches, for each of the two diagrams.
        let comparisonsMade = comparisons.value - comparisonsBefore
        #expect(comparisonsMade < 100 * stateCount)
    }
}
