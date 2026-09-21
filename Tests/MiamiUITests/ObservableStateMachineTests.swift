import Observation
import Testing
import MiamiStateMachine
import MiamiUI

/// The observable state machine hears from its state machine a moment after
/// something happens, so the tests wait for a state. The time limit makes a
/// state never heard of fail the test, where it would wait forever.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct ObservableStateMachineTests {

    private func makeStateMachine(initialState: DoorState = .closed) throws -> DoorStateMachine {
        try StateMachine(transitions: DoorFixture.transitions, initialState: initialState)
    }

    /// Waits for the observable door to hear that the door is at a state.
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    private func wait(for state: DoorState, at door: ObservableDoor) async {
        while door.state != state, !Task.isCancelled {
            await Task.yield()
        }
    }

    // MARK: - State

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func startsAtTheInitialState() throws {
        let door = ObservableStateMachine(try makeStateMachine(initialState: .locked))

        // Known at once, before anything is heard from the state machine.
        #expect(door.state == .locked)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func followsTheEventsItSends() async throws {
        let door = ObservableStateMachine(try makeStateMachine())

        door.send(.open)
        await wait(for: .opened, at: door)

        #expect(door.state == .opened)
        #expect(await door.stateMachine.state == .opened)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func followsEventsProcessedByOthers() async throws {
        let stateMachine = try makeStateMachine()
        let door = ObservableStateMachine(stateMachine)

        await stateMachine.process(.lock)
        await wait(for: .locked, at: door)

        #expect(door.state == .locked)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func catchesUpWithStateMachineAlreadyInUse() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.open)

        // The initial state until heard from, and then where the state machine is.
        let door = ObservableStateMachine(stateMachine)
        #expect(door.state == .closed)

        await wait(for: .opened, at: door)
        #expect(door.state == .opened)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func rejectedEventChangesNothing() async throws {
        let door = ObservableStateMachine(try makeStateMachine())

        // A closed door cannot be closed or unlocked. Opening it is what is waited for.
        door.send(.close)
        door.send(.unlock)
        door.send(.open)
        await wait(for: .opened, at: door)

        #expect(await door.stateMachine.rejectedEventsCount == 2)
        #expect(await door.stateMachine.stateChangeCount == 1)
    }

    // MARK: - Sending events

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func eventsAreProcessedInTheOrderSent() async throws {
        let door = ObservableStateMachine(try makeStateMachine())

        // Every event is only accepted after the one before it.
        let events: [DoorEvent] = [.open, .close, .lock, .unlock, .open, .close, .lock, .unlock, .open, .breakDown]
        for event in events {
            door.send(event)
        }
        await wait(for: .broken, at: door)

        #expect(await door.stateMachine.stateChangeCount == events.count)
        #expect(await door.stateMachine.rejectedEventsCount == 0, "An event out of order would be rejected.")
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func eventsSentAreProcessedAlsoWhenLetGoOf() async throws {
        let stateMachine = try makeStateMachine()
        let states = await stateMachine.stateStream()

        var door: ObservableDoor? = ObservableStateMachine(stateMachine)
        door?.send(.open)
        door?.send(.breakDown)
        door = nil

        // The stream of states finishes when the door is broken.
        var last: DoorState?
        for await state in states {
            last = state
        }
        #expect(last == .broken)
    }

    // MARK: - Questions about the current state

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func acceptsEventsWithTransitionFromTheCurrentState() async throws {
        let door = ObservableStateMachine(try makeStateMachine())

        #expect(door.accepts(.open))
        #expect(door.accepts(.close) == false)
        #expect(door.eventsFromCurrent == [.open, .lock, .breakDown])

        door.send(.lock)
        await wait(for: .locked, at: door)

        #expect(door.accepts(.unlock))
        #expect(door.accepts(.breakDown) == false, "A locked door cannot break down.")
        #expect(door.eventsFromCurrent == [.unlock])
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func isAtEndingStateWhenNoEventsAreAccepted() async throws {
        let door = ObservableStateMachine(try makeStateMachine())
        #expect(door.isAtEndingState == false)

        door.send(.breakDown)
        await wait(for: .broken, at: door)

        #expect(door.isAtEndingState)
        #expect(door.eventsFromCurrent.isEmpty)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func followsStateMachineAlreadyAtEndingState() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.breakDown)

        let door = ObservableStateMachine(stateMachine)
        await wait(for: .broken, at: door)

        // Nothing is accepted, but sending is harmless.
        door.send(.open)
        #expect(door.isAtEndingState)
    }

    // MARK: - Observation

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func changeOfStateIsObserved() async throws {
        let door = ObservableStateMachine(try makeStateMachine())

        await confirmation { stateWillChange in
            withObservationTracking {
                _ = door.state
            } onChange: {
                stateWillChange()
            }

            door.send(.open)
            await wait(for: .opened, at: door)
        }
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func questionsAboutTheCurrentStateAreObservedToo() async throws {
        let door = ObservableStateMachine(try makeStateMachine())

        // What a view asks to enable a button depends on the state.
        await confirmation { answerWillChange in
            withObservationTracking {
                _ = door.accepts(.close)
            } onChange: {
                answerWillChange()
            }

            door.send(.open)
            await wait(for: .opened, at: door)
        }
    }

    // MARK: - Life cycle

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func stopsFollowingTheStateMachineWhenLetGoOf() async throws {
        let stateMachine = try makeStateMachine()

        var door: ObservableDoor? = ObservableStateMachine(stateMachine)
        while await stateMachine.streamCount.states != 1, !Task.isCancelled {
            await Task.yield()
        }

        door = nil
        _ = door

        // The state machine forgets the stream of states, in a task of its own.
        while await stateMachine.streamCount.states != 0, !Task.isCancelled {
            await Task.yield()
        }
        #expect(await stateMachine.streamCount.states == 0)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func doesNotKeepTheStateMachineAliveWhenLetGoOf() async throws {
        weak var stateMachine: DoorStateMachine?

        do {
            let door = ObservableStateMachine(try makeStateMachine())
            stateMachine = door.stateMachine

            door.send(.open)
            await wait(for: .opened, at: door)
        }

        // The tasks of the observable door have the state machine, and have
        // to end for the state machine to be deallocated.
        while stateMachine != nil, !Task.isCancelled {
            await Task.yield()
        }
        #expect(stateMachine == nil)
    }

    // MARK: - Creating the state machine

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func createsItsOwnStateMachine() async throws {
        let door = try ObservableStateMachine(transitions: DoorFixture.transitions, initialState: .closed, logCapacity: 1)

        door.send(.open)
        door.send(.close)
        await wait(for: .opened, at: door)
        await wait(for: .closed, at: door)

        #expect(await door.stateMachine.transitionLog.count == 1)
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func inconsistentDefinitionThrows() throws {
        // Opening a closed door would lead to both opened and broken.
        let conflict = DoorTransition(from: .closed, event: .open, to: .broken)

        let error = try #require(throws: DoorStateMachine.DefinitionError.self) {
            try ObservableStateMachine(transitions: DoorFixture.transitions.union([conflict]), initialState: .closed)
        }

        #expect(error.conflictingTransitions == [conflict, StateTransition(from: .closed, event: .open, to: .opened)])
    }
}
