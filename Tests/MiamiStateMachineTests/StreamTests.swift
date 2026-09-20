import Testing
import MiamiStateMachine

/// All elements of a stream. Waits for the stream to finish.
private func elements<Element: Sendable>(of stream: AsyncStream<Element>) async -> [Element] {
    var elements: [Element] = []
    for await element in stream {
        elements.append(element)
    }
    return elements
}

/// A stream not working shows as a consumer waiting forever, so
/// the time limit is what makes these tests fail instead of hang.
@Suite(.timeLimit(.minutes(1)))
struct StreamTests {

    private func makeStateMachine(initialState: OrderState = .cart) throws -> OrderStateMachine {
        try StateMachine(transitions: OrderFixture.transitions, initialState: initialState)
    }

    // MARK: - Transition stream

    @Test func deliversTransitionsInOrderAndFinishesAtEndingState() async throws {
        let stateMachine = try makeStateMachine()
        let stream = await stateMachine.transitionStream()

        // There is nothing to ship in the cart, so the first ship is rejected.
        for event in [.addItem, .ship, .checkOut, .pay, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        #expect(await elements(of: stream) == [
            StateTransition(from: .cart, event: .addItem, to: .cart),
            StateTransition(from: .cart, event: .checkOut, to: .checkout),
            StateTransition(from: .checkout, event: .pay, to: .paid),
            StateTransition(from: .paid, event: .ship, to: .shipped),
            StateTransition(from: .shipped, event: .deliver, to: .delivered),
        ])
    }

    @Test func consumerTaskGetsTransitionsProcessedWhileItRuns() async throws {
        let stateMachine = try makeStateMachine()
        let stream = await stateMachine.transitionStream()
        let consumer = Task { await elements(of: stream) }

        for event in [.buyNow, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        #expect(await consumer.value.map(\.event) == [.buyNow, .ship, .deliver])
    }

    @Test func everyStreamGetsEveryTransition() async throws {
        let stateMachine = try makeStateMachine()
        let first = await stateMachine.transitionStream()
        let second = await stateMachine.transitionStream()

        for event in [.buyNow, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        #expect(await elements(of: first).map(\.event) == [.buyNow, .ship, .deliver])
        #expect(await elements(of: second).map(\.event) == [.buyNow, .ship, .deliver])
    }

    /// Delivered and cancelled are ending states. Returned is not part of any transition.
    @Test(arguments: [OrderState.delivered, .cancelled, .returned])
    func streamCreatedAtEndingStateIsFinished(state: OrderState) async throws {
        let stateMachine = try makeStateMachine(initialState: state)
        let stream = await stateMachine.transitionStream()

        #expect(await elements(of: stream) == [])
    }

    @Test func streamOfStateMachineWithoutTransitionsIsFinished() async throws {
        let stateMachine = try OrderStateMachine(transitions: [], initialState: .cart)
        let stream = await stateMachine.transitionStream()

        #expect(await elements(of: stream) == [])
    }

    @Test func streamCreatedAfterReachingEndingStateIsFinished() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.cancel)
        let stream = await stateMachine.transitionStream()

        #expect(await elements(of: stream) == [])
    }

    @Test func cancellingConsumerEndsOnlyItsOwnStream() async throws {
        let stateMachine = try makeStateMachine()
        let cancelled = await stateMachine.transitionStream()
        let kept = await stateMachine.transitionStream()

        let consumer = Task { await elements(of: cancelled) }
        await stateMachine.process(.checkOut)
        consumer.cancel()
        _ = await consumer.value

        // A cancelled consumer should not stop anyone from listening later on.
        let createdAfterCancel = await stateMachine.transitionStream()
        for event in [.pay, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        #expect(await elements(of: kept).map(\.event) == [.checkOut, .pay, .ship, .deliver])
        #expect(await elements(of: createdAfterCancel).map(\.event) == [.pay, .ship, .deliver])
    }

    @Test func bufferingPolicyLimitsWhatIsKeptUntilConsumed() async throws {
        let stateMachine = try makeStateMachine()
        let stream = await stateMachine.transitionStream(bufferingPolicy: .bufferingNewest(1))

        for event in [.buyNow, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        #expect(await elements(of: stream).map(\.event) == [.deliver])
    }

    // MARK: - Rejected event stream

    @Test func deliversRejectedEventsWithTheStateTheyWereRejectedAt() async throws {
        var stateMachine: OrderStateMachine? = try makeStateMachine()
        let stream = try #require(await stateMachine?.rejectedEventStream())

        // Rejected are shipping from the cart, checking out at the checkout
        // and cancelling when delivered. Events are rejected at an ending
        // state as well, so reaching delivered does not finish the stream.
        for event in [.ship, .checkOut, .checkOut, .pay, .ship, .deliver, .cancel] as [OrderEvent] {
            await stateMachine?.process(event)
        }

        // The stream finishes when the state machine is deallocated.
        stateMachine = nil
        let rejected = await elements(of: stream)

        #expect(rejected.map { $0.from } == [.cart, .checkout, .delivered])
        #expect(rejected.map { $0.for } == [.ship, .checkOut, .cancel])
    }

    @Test func everyStreamGetsEveryRejectedEvent() async throws {
        var stateMachine: OrderStateMachine? = try makeStateMachine()
        let first = try #require(await stateMachine?.rejectedEventStream())
        let second = try #require(await stateMachine?.rejectedEventStream())

        await stateMachine?.process(.ship)
        await stateMachine?.process(.deliver)
        stateMachine = nil

        #expect(await elements(of: first).map { $0.for } == [.ship, .deliver])
        #expect(await elements(of: second).map { $0.for } == [.ship, .deliver])
    }

    // MARK: - Life cycle

    @Test func deallocatedStateMachineFinishesItsStreams() async throws {
        var stateMachine: OrderStateMachine? = try makeStateMachine()
        let transitions = try #require(await stateMachine?.transitionStream())
        let rejectedEvents = try #require(await stateMachine?.rejectedEventStream())

        await stateMachine?.process(.checkOut)
        await stateMachine?.process(.ship)
        stateMachine = nil

        // What was delivered before is still there to consume.
        #expect(await elements(of: transitions).map(\.event) == [.checkOut])
        #expect(await elements(of: rejectedEvents).map { $0.for } == [.ship])
    }

    @Test func streamsNoLongerInUseAreForgotten() async throws {
        let stateMachine = try makeStateMachine()
        let transitions = await stateMachine.transitionStream()
        let rejectedEvents = await stateMachine.rejectedEventStream()
        #expect(await stateMachine.streamCount.transitions == 1)
        #expect(await stateMachine.streamCount.rejectedEvents == 1)

        // Streams of cancelled consumers.
        let consumers = [
            Task { _ = await elements(of: transitions) },
            Task { _ = await elements(of: rejectedEvents) },
        ]
        for consumer in consumers {
            consumer.cancel()
            await consumer.value
        }

        // Streams let go of without ever being used.
        _ = await stateMachine.transitionStream()
        _ = await stateMachine.rejectedEventStream()

        // The state machine is told by a task of its own, so give it time to run.
        while await stateMachine.streamCount != (0, 0), !Task.isCancelled {
            await Task.yield()
        }

        #expect(await stateMachine.streamCount.transitions == 0)
        #expect(await stateMachine.streamCount.rejectedEvents == 0)
    }

    @Test func streamsFinishedAtEndingStateAreForgotten() async throws {
        let stateMachine = try makeStateMachine()
        let stream = await stateMachine.transitionStream()
        await stateMachine.process(.cancel)

        #expect(await stateMachine.streamCount.transitions == 0)
        #expect(await elements(of: stream).map(\.event) == [.cancel])
    }

    // MARK: - Concurrent use

    /// Processes events from many tasks at once. The state machine
    /// only moves between the cart and the checkout.
    /// - Returns: A stream of all transitions made, which finishes as
    /// the state machine is deallocated on return, and what the state
    /// machine knew about the events when all of them were processed.
    private func processEventsConcurrently(
        taskCount: Int,
        eventsPerTask: Int
    ) async throws -> (
        stream: OrderStateMachine.TransitionStream,
        processed: Int,
        stateChanges: Int,
        rejected: Int,
        log: [OrderTransition],
        state: OrderState
    ) {
        let stateMachine = try makeStateMachine()
        let stream = await stateMachine.transitionStream()

        // Delivering is always rejected, the others depend on the current state.
        let events: [OrderEvent] = [.checkOut, .editCart, .addItem, .deliver]

        await withTaskGroup(of: Void.self) { group in
            for task in 0 ..< taskCount {
                group.addTask {
                    for step in 0 ..< eventsPerTask {
                        await stateMachine.process(events[(task + step) % events.count])
                    }
                }
            }
        }

        var log = await stateMachine.transitionLog
        var transitions: [OrderTransition] = []
        while let transition = log.popOldest() {
            transitions.append(transition)
        }

        return (stream,
                await stateMachine.processedEventsCount,
                await stateMachine.stateChangeCount,
                await stateMachine.rejectedEventsCount,
                transitions,
                await stateMachine.state)
    }

    @Test func concurrentEventsKeepTheStateMachineConsistent() async throws {
        let result = try await processEventsConcurrently(taskCount: 50, eventsPerTask: 200)
        let streamed = await elements(of: result.stream)

        #expect(result.processed == 10_000)
        #expect(result.stateChanges + result.rejected == 10_000)
        #expect(result.rejected >= 2_500, "Delivering is a quarter of the events, and is always rejected.")

        // Every transition is logged and streamed once, in the order made.
        #expect(result.log.count == result.stateChanges)
        #expect(streamed == result.log)

        // Every transition starts from where the transition before it ended.
        #expect(result.log.first?.from == .cart)
        #expect(result.log.last?.to == result.state)
        let brokenLinks = zip(result.log, result.log.dropFirst()).filter { $0.to != $1.from }
        #expect(brokenLinks.isEmpty)
    }
}
