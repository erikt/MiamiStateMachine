import Foundation
import Testing
import MiamiStateMachine

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
/// much work the state machine does, without measuring time. Searching all
/// transitions compares the state of every one of them.
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

/// The work done by a state machine should not depend on the number
/// of transitions, for generated definitions to be usable.
struct LargeDefinitionTests {
    private let stateCount = 2_000
    private let comparisons = ComparisonCount()

    private func state(_ number: Int) -> CountedState {
        CountedState(number: number % stateCount, comparisons: comparisons)
    }

    /// A ring of states, where the event 0 leads from every state to the next one.
    private func makeRing() -> Set<TransitionRule<Int, CountedState>> {
        Set((0 ..< stateCount).map { number in
            TransitionRule(from: state(number), event: 0, to: state(number + 1))
        })
    }

    @Test func creatingStateMachineDoesNotCompareAllTransitionsWithEachOther() throws {
        let transitions = makeRing()
        let comparisonsBefore = comparisons.value

        _ = try StateMachine(transitions: transitions, initialState: state(0))

        // Comparing every transition with every other is 4 000 000 comparisons.
        // Looking the states up in hash tables is about 15 for every transition.
        let comparisonsMade = comparisons.value - comparisonsBefore
        #expect(comparisonsMade < 100 * stateCount)
    }

    @Test func processingEventDoesNotSearchAllTransitions() async throws {
        let stateMachine = try StateMachine(transitions: makeRing(), initialState: state(0))
        let comparisonsBefore = comparisons.value

        let eventCount = 500
        for _ in 0 ..< eventCount {
            await stateMachine.process(0)
        }

        // Searching all transitions once for every event is 1 000 000 comparisons.
        let comparisonsMade = comparisons.value - comparisonsBefore
        #expect(comparisonsMade < 20 * eventCount)
        #expect(await stateMachine.state == state(eventCount))
        #expect(await stateMachine.stateChangeCount == eventCount)
    }

    @Test func questionsAboutWhatLeadsToAStateDoNotSearchAllTransitions() throws {
        let stateMachine = try StateMachine(transitions: makeRing(), initialState: state(0))
        let comparisonsBefore = comparisons.value

        // In the ring, one transition leads to every state, from the state before it.
        #expect(stateMachine.transitions(to: state(500)) == [TransitionRule(from: state(499), event: 0, to: state(500))])
        #expect(stateMachine.transitions(to: state(500), for: 0).count == 1)
        #expect(stateMachine.events(to: state(500)) == [0])

        // Searching all transitions compares the state of every one of them,
        // 2 000 comparisons for each question.
        let comparisonsMade = comparisons.value - comparisonsBefore
        #expect(comparisonsMade < 100)
    }

    @Test func checksOfTheDefinitionDoNotSearchFromEveryState() throws {
        // The ring, and a way out of it to an ending state.
        let ending = CountedState(number: stateCount, comparisons: comparisons)
        let transitions = makeRing().union([TransitionRule(from: state(0), event: 1, to: ending)])
        let stateMachine = try StateMachine(transitions: transitions, initialState: state(0))
        let comparisonsBefore = comparisons.value

        #expect(stateMachine.states.count == stateCount + 1)
        #expect(stateMachine.endingStates == [ending])
        #expect(stateMachine.unreachableStates.isEmpty)
        #expect(stateMachine.statesWithoutPathToEndingState.isEmpty)
        #expect(stateMachine.hasCycle)

        // Asking for the reachable states of every state, one at a time, is
        // 4 000 000 states to put in sets, and about as many comparisons.
        let comparisonsMade = comparisons.value - comparisonsBefore
        #expect(comparisonsMade < 100 * stateCount)
    }

    @Test func conflictIsFoundInLargeDefinition() throws {
        let conflict = TransitionRule(from: state(1_000), event: 0, to: state(7))
        let transitions = makeRing().union([conflict])

        let error = try #require(throws: StateMachine<Int, CountedState>.DefinitionError.self) {
            try StateMachine(transitions: transitions, initialState: state(0))
        }

        #expect(error.conflictingTransitions == [
            conflict,
            TransitionRule(from: state(1_000), event: 0, to: state(1_001)),
        ])
    }
}
