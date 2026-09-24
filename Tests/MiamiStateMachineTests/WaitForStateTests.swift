import Testing
import MiamiStateMachine

/// Waiting that does not work shows as a task waiting forever, so
/// the time limit is what makes these tests fail instead of hang.
@Suite(.timeLimit(.minutes(1)))
struct WaitForStateTests {

    private func makeStateMachine(initialState: OrderState = .cart) throws -> OrderStateMachine {
        try StateMachine(transitions: OrderFixture.transitions, initialState: initialState)
    }

    /// Starts waiting for a state in a task of its own, and returns when the
    /// task is waiting, so that the events processed next are not missed.
    private func startWaiting(for state: OrderState, at stateMachine: OrderStateMachine) async -> Task<Bool, Never> {
        let waiter = Task { await stateMachine.wait(for: state) }
        while await stateMachine.streamCount.states == 0, !Task.isCancelled {
            await Task.yield()
        }
        return waiter
    }

    /// What a task waiting for a state returned. The task is cancelled with
    /// the test, so that waiting forever fails at the time limit instead of hanging.
    private func result(of waiter: Task<Bool, Never>) async -> Bool {
        await withTaskCancellationHandler {
            await waiter.value
        } onCancel: {
            waiter.cancel()
        }
    }

    /// Processes events in one go on the state machine, without
    /// letting any other task run on it in between.
    private func process(_ events: [OrderEvent], at stateMachine: isolated OrderStateMachine) {
        for event in events {
            stateMachine.process(event)
        }
    }

    // MARK: - Reaching the state

    @Test func returnsAtOnceWhenAtTheState() async throws {
        let stateMachine = try makeStateMachine()

        #expect(await stateMachine.wait(for: .cart))
        #expect(await stateMachine.streamCount.states == 0)
    }

    @Test(arguments: [OrderState.delivered, .cancelled, .returned])
    func returnsAtOnceWhenAtTheEndingState(state: OrderState) async throws {
        let stateMachine = try makeStateMachine(initialState: state)

        #expect(await stateMachine.wait(for: state))
    }

    @Test func returnsWhenTheStateIsEntered() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .paid, at: stateMachine)

        await stateMachine.process(.checkOut)
        await stateMachine.process(.pay)

        #expect(await result(of: waiter))
    }

    @Test func returnsForAStateEnteredAndLeftAgain() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .checkout, at: stateMachine)

        // Checkout is entered and left again before the waiting task can
        // run, and the state machine gets to paid, from where there is no
        // way back to checkout. Adding an item goes first, as a task already
        // waiting for a state is handed the first one without buffering it.
        await process([.addItem, .checkOut, .pay], at: stateMachine)

        #expect(await result(of: waiter))
    }

    @Test func returnsWhenTheEndingStateIsEntered() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .delivered, at: stateMachine)

        for event in [.buyNow, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        #expect(await result(of: waiter))
    }

    @Test func aTransitionBackToTheSameStateDoesNotEndTheWaiting() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .checkout, at: stateMachine)

        await stateMachine.process(.addItem)
        await stateMachine.process(.addItem)
        await stateMachine.process(.checkOut)

        #expect(await result(of: waiter))
    }

    @Test func rejectedEventsDoNotEndTheWaiting() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .shipped, at: stateMachine)

        await stateMachine.process(.ship)
        await stateMachine.process(.deliver)
        await stateMachine.process(.buyNow)
        await stateMachine.process(.ship)

        #expect(await result(of: waiter))
    }

    @Test func everyTaskWaitingForTheStateReturns() async throws {
        let stateMachine = try makeStateMachine()
        let first = Task { await stateMachine.wait(for: .shipped) }
        let second = Task { await stateMachine.wait(for: .shipped) }
        while await stateMachine.streamCount.states < 2, !Task.isCancelled {
            await Task.yield()
        }

        await stateMachine.process(.buyNow)
        await stateMachine.process(.ship)

        #expect(await result(of: first))
        #expect(await result(of: second))
    }

    // MARK: - Not reaching the state

    @Test func returnsAtOnceWhenTheStateCannotBeReached() async throws {
        let stateMachine = try makeStateMachine(initialState: .paid)

        #expect(await !stateMachine.wait(for: .checkout))
        #expect(await !stateMachine.wait(for: .cart))
    }

    @Test func returnsAtOnceForAStateNotInAnyTransition() async throws {
        let stateMachine = try makeStateMachine()

        #expect(await !stateMachine.wait(for: .returned))
    }

    @Test func returnsAtOnceAtAnotherEndingState() async throws {
        let stateMachine = try makeStateMachine(initialState: .cancelled)

        #expect(await !stateMachine.wait(for: .delivered))
    }

    @Test func returnsWhenAnotherEndingStateIsEntered() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .delivered, at: stateMachine)

        await stateMachine.process(.cancel)

        #expect(await !result(of: waiter))
    }

    /// Paid is not an ending state, but there is no way back from it to the checkout.
    @Test func returnsWhenTheStateCanNoLongerBeReached() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .checkout, at: stateMachine)

        await stateMachine.process(.buyNow)

        #expect(await !result(of: waiter))
        #expect(await !stateMachine.isAtEndingState)
    }

    @Test func returnsWhenCancelled() async throws {
        let stateMachine = try makeStateMachine()
        let waiter = await startWaiting(for: .delivered, at: stateMachine)

        waiter.cancel()

        #expect(await !result(of: waiter))
    }

    // MARK: - Streams

    /// Each way of ending has a state machine of its own, as a stream being
    /// forgotten would let `startWaiting` return before the next task waits.
    @Test func streamIsForgottenWhenTheWaitingEnds() async throws {
        let reachedMachine = try makeStateMachine()
        let reached = await startWaiting(for: .checkout, at: reachedMachine)
        await reachedMachine.process(.checkOut)
        #expect(await result(of: reached))

        let unreachableMachine = try makeStateMachine()
        let unreachable = await startWaiting(for: .checkout, at: unreachableMachine)
        await unreachableMachine.process(.buyNow)
        #expect(await !result(of: unreachable))

        let cancelledMachine = try makeStateMachine()
        let cancelled = await startWaiting(for: .delivered, at: cancelledMachine)
        cancelled.cancel()
        #expect(await !result(of: cancelled))

        // The state machine is told by a task of its own, so give it time to run.
        for stateMachine in [reachedMachine, unreachableMachine, cancelledMachine] {
            while await stateMachine.streamCount.states != 0, !Task.isCancelled {
                await Task.yield()
            }
            #expect(await stateMachine.streamCount.states == 0)
        }
    }
}
