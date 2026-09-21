import Testing
import MiamiStateMachine

struct MiamiStateMachineTests {

    // MARK: - State machine definitions for testing

    enum S1 {
        case s1, s2, s3, end
    }

    enum E1 {
        case s1ToS2, s2ToS3, s1ToS3, s3ToEnd
    }

    let t1: Set<StateTransition<E1, S1>> = [
        StateTransition(from: .s1, event: .s1ToS2, to: .s2),
        StateTransition(from: .s1, event: .s1ToS3, to: .s3),
        StateTransition(from: .s2, event: .s2ToS3, to: .s3),
        StateTransition(from: .s3, event: .s3ToEnd, to: .end)
    ]

    // --

    enum S2 {
        case s1, s2, s3
    }

    enum E2 {
        case e1, e2, e3
    }

    let illegalT: Set<StateTransition<E2, S2>> = [
        StateTransition(from: .s1, event: .e1, to: .s2),
        StateTransition(from: .s2, event: .e2, to: .s3),
        StateTransition(from: .s1, event: .e3, to: .s3),
        StateTransition(from: .s1, event: .e3, to: .s2)
    ]

    // --

    enum MyState {
        case s1, s2, s3
    }

    enum MyEvent {
        case e1, e2, e3, e4
    }

    typealias MyTransition = StateTransition<MyEvent, MyState>

    let transitions: Set<MyTransition> = [
        StateTransition(from: .s1, event: .e1, to: .s2),
        StateTransition(from: .s2, event: .e2, to: .s3),
        StateTransition(from: .s1, event: .e3, to: .s3),
        StateTransition(from: .s1, event: .e4, to: .s1)
    ]

    // MARK: - Tests

    @Test func startState() async throws {
        let sm1 = try StateMachine(transitions: t1, initialState: .s1)

        #expect(await sm1.isAtEndingState == false, "State machine should not have reached an end state.")
        #expect(sm1.transitionCount == 4, "State machine definition should have 4 defined transitions.")
        #expect(await sm1.canTransition(to: .end) == false, "No possible transition to end state.")
        #expect(await sm1.canTransition(to: .s2), "Should be possible to transition to s2 state from s1.")
        #expect(await sm1.transitionsFromCurrent(to: .s2).count == 1, "Should be 1 transition from current state to s2.")
        #expect(await sm1.transitionsFromCurrent(to: .end).count == 0, "Should not exist any transition to end state from s1.")
    }

    @Test func processEvent() async throws {
        let sm1 = try StateMachine(transitions: t1, initialState: .s1)
        #expect(await sm1.state == .s1, "State machine should start at s1.")

        await sm1.process(.s3ToEnd)
        #expect(await sm1.state == .s1, "State machine should not change state after processing s3ToEnd event.")
        #expect(await sm1.processedEventsCount == 1, "Processed events should be 1")
        #expect(await sm1.stateChangeCount == 0, "State changes should be 0")

        await sm1.process(.s1ToS2)
        #expect(await sm1.state == .s2, "State machine should have transitioned to s2 after processing s1ToS2 event.")

        await sm1.process(.s2ToS3)
        await sm1.process(.s3ToEnd)
        #expect(await sm1.state == .end, "State machine should be at end state.")
        #expect(await sm1.isAtEndingState, "State machine should have reached an end state.")

        #expect(await sm1.processedEventsCount == 4, "Events processed should be 4")
        #expect(await sm1.stateChangeCount == 3, "State changes should be 3")
        #expect(await sm1.rejectedEventsCount == 1, "Rejected events should be 1")
    }

    @Test func transitionLog() async throws {
        let sm1 = try StateMachine(transitions: t1, initialState: .s1)
        await sm1.process(.s1ToS2)
        await sm1.process(.s2ToS3)
        await sm1.process(.s3ToEnd)

        var log = await sm1.transitionLog
        var newest = log.popLast()
        let last = try #require(newest)
        #expect(last.from == .s3, "Transition should be from S3")
        #expect(last.to == .end, "Transition should be to end")
        #expect(last.event == .s3ToEnd, "Transition event should be s3ToEnd")

        newest = log.popLast()
        let secondLast = try #require(newest)
        #expect(secondLast.from == .s2, "Transition should be from S2")
        #expect(secondLast.to == .s3, "Transition should be to S3")
        #expect(secondLast.event == .s2ToS3, "Transition event should be s2ToS3")

        newest = log.popLast()
        let first = try #require(newest)
        #expect(first.from == .s1, "Transition should be from S1")
        #expect(first.to == .s2, "Transition should be to S2")
        #expect(first.event == .s1ToS2, "Transition event should be s1ToS2")

        newest = log.popLast()
        #expect(newest == nil, "There should be no more commited transitions")
    }

    @Test func illegalStateMachineDefinition() {
        #expect(throws: StateMachine<E2, S2>.DefinitionError.self,
                "Should not be possible to create an inconsistent state machine definition.") {
            try StateMachine(transitions: illegalT, initialState: .s1)
        }
    }

    @Test func transitionLogWithoutCapacity() async throws {
        let demoSm = try StateMachine(transitions: transitions, initialState: .s1)
        await demoSm.process(.e4)
        var log = await demoSm.transitionLog
        let expectedT1: MyTransition = StateTransition(from: .s1, event: .e4, to: .s1)
        #expect(log.last == log.first, "Last log entry and oldest log entry should be the same")
        #expect(log.count == 1, "Number of log entries should be 1")
        #expect(log.last == expectedT1, "Last log entry should be from s1")

        // Three more times back to s1, and then on to s2 and s3.
        let events: [MyEvent] = [.e4, .e4, .e4, .e1, .e2]
        for (number, event) in events.enumerated() {
            await demoSm.process(event)
            log = await demoSm.transitionLog
            #expect(log.count == number + 2, "There should be \(number + 2) log entries, not \(log.count)")
        }

        let expOld: MyTransition = StateTransition(from: .s1, event: .e4, to: .s1)
        let expLast: MyTransition = StateTransition(from: .s2, event: .e2, to: .s3)
        #expect(log.first == expOld, "Oldest entry is not expected")
        #expect(log.last == expLast, "Last entry is not expected")
    }
}
