import Testing
import MiamiStateMachine

/// Waiting that does not work shows as a task waiting forever, so
/// the time limit is what makes these tests fail instead of hang.
@Suite(.timeLimit(.minutes(1)))
struct TimedEventTests {

    private typealias Timeout = Task<TransitionEvent<OrderEvent, OrderState>?, any Error>

    private let clock = TestClock()

    private func makeStateMachine(initialState: OrderState = .cart) throws -> OrderStateMachine {
        try StateMachine(transitions: OrderFixture.transitions, initialState: initialState)
    }

    /// Starts a timeout in a task of its own, and returns when it is waiting
    /// for both the time and a transition, so the events processed next count.
    private func startTimeout(_ event: OrderEvent,
                              ifStillAt state: OrderState,
                              at stateMachine: OrderStateMachine) async -> Timeout
    {
        let clock = clock
        let timeout = Task {
            try await stateMachine.process(event, after: .seconds(10), ifStillAt: state, clock: clock)
        }
        while !Task.isCancelled {
            let streams = await stateMachine.streamCount.states
            if clock.sleeperCount > 0, streams > 0 {
                break
            }
            await Task.yield()
        }
        return timeout
    }

    /// What a timeout returned. The task is cancelled with the test, so
    /// that waiting forever fails at the time limit instead of hanging.
    private func result(of timeout: Timeout) async throws -> TransitionEvent<OrderEvent, OrderState>? {
        try await withTaskCancellationHandler {
            try await timeout.value
        } onCancel: {
            timeout.cancel()
        }
    }

    // MARK: - Staying at the state

    @Test func eventIsProcessedWhenTheTimeHasPassed() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.cancel, ifStillAt: .cart, at: stateMachine)

        clock.advance(by: .seconds(9))
        await Task.yield()
        #expect(await stateMachine.processedEventsCount == 0, "Not processed before the time has passed.")

        clock.advance(by: .seconds(1))

        #expect(try await result(of: timeout) == TransitionEvent(from: .cart, event: .cancel, to: .cancelled))
        #expect(await stateMachine.state == .cancelled)
    }

    @Test func rejectedEventDoesNotEndTheWaiting() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.cancel, ifStillAt: .cart, at: stateMachine)

        // There is nothing to ship in the cart, so nothing changes.
        await stateMachine.process(.ship)
        clock.advance(by: .seconds(10))

        #expect(try await result(of: timeout)?.to == .cancelled)
    }

    @Test func eventRejectedWhenTheTimeHasPassedIsCountedAsRejected() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.deliver, ifStillAt: .cart, at: stateMachine)

        clock.advance(by: .seconds(10))

        #expect(try await result(of: timeout) == nil)
        #expect(await stateMachine.rejectedEventsCount == 1)
    }

    /// Nothing ever leaves an ending state, so only the time ends the waiting.
    @Test func timeoutAtAnEndingStateWaitsForTheTime() async throws {
        let stateMachine = try makeStateMachine(initialState: .cancelled)
        let clock = clock
        let timeout = Task {
            try await stateMachine.process(.checkOut, after: .seconds(10), ifStillAt: .cancelled, clock: clock)
        }
        while clock.sleeperCount == 0, !Task.isCancelled {
            await Task.yield()
        }

        clock.advance(by: .seconds(10))

        #expect(try await result(of: timeout) == nil)
        #expect(await stateMachine.rejectedEventsCount == 1)
    }

    // MARK: - Leaving the state

    @Test func transitionEndsTheWaitingAtOnce() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.cancel, ifStillAt: .cart, at: stateMachine)

        await stateMachine.process(.checkOut)

        // The clock never moves, so only the transition can end the waiting.
        #expect(try await result(of: timeout) == nil)
        #expect(await stateMachine.processedEventsCount == 1, "The timed event is never processed.")
        #expect(await stateMachine.state == .checkout)
    }

    @Test func transitionBackToTheSameStateCountsAsLeaving() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.cancel, ifStillAt: .cart, at: stateMachine)

        await stateMachine.process(.addItem)

        #expect(try await result(of: timeout) == nil)
        #expect(await stateMachine.state == .cart)
        #expect(await stateMachine.processedEventsCount == 1)
    }

    @Test func transitionToAnEndingStateEndsTheWaiting() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.checkOut, ifStillAt: .cart, at: stateMachine)

        await stateMachine.process(.cancel)

        #expect(try await result(of: timeout) == nil)
    }

    @Test func notAtTheStateReturnsAtOnce() async throws {
        let stateMachine = try makeStateMachine()

        // The clock never moves, and nothing is waited for.
        let made = try await stateMachine.process(.pay, after: .seconds(10), ifStillAt: .checkout, clock: clock)

        #expect(made == nil)
        #expect(clock.sleeperCount == 0)
        #expect(await stateMachine.processedEventsCount == 0)
    }

    // MARK: - Cancelling

    @Test func cancellingThrowsAndProcessesNothing() async throws {
        let stateMachine = try makeStateMachine()
        let timeout = await startTimeout(.cancel, ifStillAt: .cart, at: stateMachine)

        timeout.cancel()

        await #expect(throws: CancellationError.self) {
            try await timeout.value
        }
        clock.advance(by: .seconds(10))
        #expect(await stateMachine.processedEventsCount == 0)
        #expect(clock.sleeperCount == 0)
    }

    @Test func streamIsForgottenWhenTheWaitingEnds() async throws {
        let passed = try makeStateMachine()
        let passedTimeout = await startTimeout(.cancel, ifStillAt: .cart, at: passed)
        clock.advance(by: .seconds(10))
        _ = try await result(of: passedTimeout)

        let left = try makeStateMachine()
        let leftTimeout = await startTimeout(.cancel, ifStillAt: .cart, at: left)
        await left.process(.checkOut)
        _ = try await result(of: leftTimeout)

        let cancelled = try makeStateMachine()
        let cancelledTimeout = await startTimeout(.cancel, ifStillAt: .cart, at: cancelled)
        cancelledTimeout.cancel()
        _ = try? await cancelledTimeout.value

        // The state machine is told by a task of its own, so give it time to run.
        for stateMachine in [passed, left, cancelled] {
            while await stateMachine.streamCount.states != 0, !Task.isCancelled {
                await Task.yield()
            }
            #expect(await stateMachine.streamCount.states == 0)
        }
    }

    // MARK: - The continuous clock

    @Test func continuousClockIsTheDefault() async throws {
        let stateMachine = try makeStateMachine()

        let made = try await stateMachine.process(.cancel, after: .milliseconds(20), ifStillAt: .cart)

        #expect(made?.to == .cancelled)
    }
}
