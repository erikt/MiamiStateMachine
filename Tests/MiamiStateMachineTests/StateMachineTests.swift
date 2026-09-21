import Testing
import MiamiStateMachine

struct StateMachineTests {

    private func makeStateMachine(initialState: OrderState = .cart) throws -> OrderStateMachine {
        try StateMachine(transitions: OrderFixture.transitions, initialState: initialState)
    }

    // MARK: - Creation

    @Test func transitionsInConflictAreReported() throws {
        // Paying at the checkout would lead to both paid and cancelled.
        let conflict = OrderTransition(from: .checkout, event: .pay, to: .cancelled)
        let transitions = OrderFixture.transitions.union([conflict])

        let error = try #require(throws: OrderStateMachine.DefinitionError.self) {
            try StateMachine(transitions: transitions, initialState: .cart)
        }

        #expect(error.conflictingTransitions == [
            StateTransition(from: .checkout, event: .pay, to: .paid),
            conflict,
        ])
    }

    @Test func everyConflictIsReportedAtOnce() throws {
        let transitions: Set<OrderTransition> = [
            // Checking out leads three ways from the cart.
            StateTransition(from: .cart, event: .checkOut, to: .checkout),
            StateTransition(from: .cart, event: .checkOut, to: .paid),
            StateTransition(from: .cart, event: .checkOut, to: .cancelled),
            // Shipping leads two ways from paid.
            StateTransition(from: .paid, event: .ship, to: .shipped),
            StateTransition(from: .paid, event: .ship, to: .delivered),
            // Not part of any conflict.
            StateTransition(from: .cart, event: .cancel, to: .cancelled),
            StateTransition(from: .shipped, event: .deliver, to: .delivered),
        ]

        let error = try #require(throws: OrderStateMachine.DefinitionError.self) {
            try StateMachine(transitions: transitions, initialState: .cart)
        }

        #expect(error.conflictingTransitions == transitions.filter { $0.event == .checkOut || $0.event == .ship })
    }

    @Test func errorDescribesManyConflictsInOrder() throws {
        // Many conflicts, as a few could come out sorted without being sorted.
        let names = ["j", "c", "h", "a", "f", "i", "b", "e", "g", "d"]
        let transitions = Set(names.map { StateTransition(from: "start", event: "go", to: $0) })

        let error = try #require(throws: StateMachine<String, String>.DefinitionError.self) {
            try StateMachine(transitions: transitions, initialState: "start")
        }

        let conflicts = names.sorted().map { "start --(go)--> \($0)" }.joined(separator: ", ")
        #expect(error.description.hasSuffix("to different states: \(conflicts)"))
    }

    @Test func errorDescribesTheConflictTheSameWayEveryTime() throws {
        let transitions: Set<OrderTransition> = [
            StateTransition(from: .checkout, event: .pay, to: .paid),
            StateTransition(from: .checkout, event: .pay, to: .cancelled),
            StateTransition(from: .cart, event: .checkOut, to: .checkout),
        ]

        let error = try #require(throws: OrderStateMachine.DefinitionError.self) {
            try StateMachine(transitions: transitions, initialState: .cart)
        }

        let expected = "The transitions do not define a consistent state machine. "
            + "The same event leads from the same state to different states: "
            + "checkout --(pay)--> cancelled, checkout --(pay)--> paid"
        #expect(error.description == expected)
        #expect(error.localizedDescription == expected)
    }

    @Test func consistentDefinitionIsAccepted() {
        let transitions: Set<OrderTransition> = [
            // Two events between the same two states.
            StateTransition(from: .paid, event: .ship, to: .shipped),
            StateTransition(from: .paid, event: .shipExpress, to: .shipped),
            // The same event from two states, leading to different states.
            StateTransition(from: .cart, event: .cancel, to: .cancelled),
            StateTransition(from: .checkout, event: .cancel, to: .cart),
            // A transition leading back to the same state.
            StateTransition(from: .cart, event: .addItem, to: .cart),
        ]

        #expect(throws: Never.self) {
            try StateMachine(transitions: transitions, initialState: .cart)
        }
    }

    @Test func initialStateWithoutTransitionsIsAccepted() async throws {
        // Returned is not part of any transition.
        let stateMachine = try makeStateMachine(initialState: .returned)

        #expect(await stateMachine.isAtEndingState)

        await stateMachine.process(.cancel)
        #expect(await stateMachine.rejectedEventsCount == 1, "Every event should be rejected.")
    }

    // MARK: - Processing events

    @Test func processReturnsTheTransitionMade() async throws {
        let stateMachine = try makeStateMachine()

        #expect(await stateMachine.process(.checkOut) == TransitionMade(from: .cart, event: .checkOut, to: .checkout))
        #expect(await stateMachine.process(.editCart) == TransitionMade(from: .checkout, event: .editCart, to: .cart))

        // Leading back to the same state is a transition as well.
        #expect(await stateMachine.process(.addItem) == TransitionMade(from: .cart, event: .addItem, to: .cart))
    }

    @Test func processReturnsNilForRejectedEvent() async throws {
        let stateMachine = try makeStateMachine()

        #expect(await stateMachine.process(.ship) == nil, "There is nothing to ship in the cart.")
        #expect(await stateMachine.state == .cart)

        await stateMachine.process(.cancel)
        #expect(await stateMachine.process(.checkOut) == nil, "Every event is rejected at an ending state.")
    }

    @Test func everyTaskLearnsWhatItsOwnEventsLedTo() async throws {
        let stateMachine = try makeStateMachine()

        // The state machine only moves between the cart and the checkout.
        // Delivering is always rejected, the others depend on the current state.
        let events: [OrderEvent] = [.checkOut, .editCart, .addItem, .deliver]

        let acceptedCount = await withTaskGroup(of: Int.self) { group in
            for task in 0 ..< 20 {
                group.addTask {
                    var acceptedCount = 0
                    for step in 0 ..< 100 {
                        let event = events[(task + step) % events.count]
                        if let transition = await stateMachine.process(event) {
                            #expect(transition.event == event)
                            acceptedCount += 1
                        }
                    }
                    return acceptedCount
                }
            }
            return await group.reduce(0, +)
        }

        #expect(await stateMachine.stateChangeCount == acceptedCount)
        #expect(await stateMachine.rejectedEventsCount == 2_000 - acceptedCount)
    }

    // MARK: - Definition

    @Test func knowsItsTransitions() throws {
        let stateMachine = try makeStateMachine()

        #expect(stateMachine.transitionCount == 10)
        #expect(stateMachine.transition(from: .cart, for: .buyNow) == StateTransition(from: .cart, event: .buyNow, to: .paid))
        #expect(stateMachine.transition(from: .cart, for: .ship) == nil, "There is nothing to ship in the cart.")

        #expect(stateMachine.transitions(from: .checkout) == [
            StateTransition(from: .checkout, event: .editCart, to: .cart),
            StateTransition(from: .checkout, event: .pay, to: .paid),
            StateTransition(from: .checkout, event: .cancel, to: .cancelled),
        ])
        #expect(stateMachine.transitions(to: .paid) == [
            StateTransition(from: .cart, event: .buyNow, to: .paid),
            StateTransition(from: .checkout, event: .pay, to: .paid),
        ])
        #expect(stateMachine.transitions(from: .cart, to: .paid) == [
            StateTransition(from: .cart, event: .buyNow, to: .paid),
        ])
        #expect(stateMachine.transitions(to: .cancelled, for: .cancel) == [
            StateTransition(from: .cart, event: .cancel, to: .cancelled),
            StateTransition(from: .checkout, event: .cancel, to: .cancelled),
            StateTransition(from: .paid, event: .cancel, to: .cancelled),
        ])
        #expect(stateMachine.transitions(to: .cancelled, for: .pay).isEmpty)
        #expect(stateMachine.transitions(from: .delivered).isEmpty)
        #expect(stateMachine.transitions(to: .returned).isEmpty)
    }

    @Test func knowsTheEventsBetweenItsStates() throws {
        let stateMachine = try makeStateMachine()

        #expect(stateMachine.events(from: .cart) == [.addItem, .checkOut, .buyNow, .cancel])
        #expect(stateMachine.events(to: .cart) == [.addItem, .editCart])
        #expect(stateMachine.events(from: .checkout, to: .cancelled) == [.cancel])
        #expect(stateMachine.events(from: .cart, to: .cart) == [.addItem])
        #expect(stateMachine.events(from: .cart, to: .delivered).isEmpty)
        #expect(stateMachine.events(from: .delivered).isEmpty)
    }

    @Test func canTransitionIsAboutOneSingleEvent() throws {
        let stateMachine = try makeStateMachine()

        #expect(stateMachine.canTransition(from: .cart, to: .paid))
        #expect(stateMachine.canTransition(from: .cart, to: .cart))
        #expect(stateMachine.canTransition(from: .cart, to: .shipped) == false, "Shipped is two events from the cart.")
        #expect(stateMachine.canTransition(from: .paid, to: .cart) == false)
    }

    @Test(arguments: [
        (OrderState.cart, false),
        (.checkout, false),
        (.paid, false),
        (.shipped, false),
        (.delivered, true),
        (.cancelled, true),
        // Not part of any transition.
        (.returned, true),
    ])
    func endingStatesHaveNoTransitionsLeadingFromThem(state: OrderState, isEndingState: Bool) throws {
        let stateMachine = try makeStateMachine()
        #expect(stateMachine.isEndingState(state) == isEndingState)
    }

    @Test func stateOnlyLeadingBackToItselfIsNotAnEndingState() async throws {
        let stateMachine = try StateMachine(transitions: [
            StateTransition(from: OrderState.cart, event: OrderEvent.addItem, to: .cart),
        ], initialState: .cart)

        #expect(stateMachine.isEndingState(.cart) == false)
        #expect(await stateMachine.isAtEndingState == false)
    }

    // MARK: - Current state

    @Test func knowsTheWaysFromAndToTheCurrentState() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.checkOut)

        #expect(await stateMachine.state == .checkout)
        #expect(await stateMachine.eventsFromCurrent == [.editCart, .pay, .cancel])
        #expect(await stateMachine.eventsToCurrent == [.checkOut])
        #expect(await stateMachine.transitionsFromCurrent == stateMachine.transitions(from: .checkout))
        #expect(await stateMachine.transitionsToCurrent == [
            StateTransition(from: .cart, event: .checkOut, to: .checkout),
        ])
        #expect(await stateMachine.transitionsFromCurrent(to: .paid) == [
            StateTransition(from: .checkout, event: .pay, to: .paid),
        ])
        #expect(await stateMachine.transitionsToCurrent(from: .cart) == [
            StateTransition(from: .cart, event: .checkOut, to: .checkout),
        ])
        #expect(await stateMachine.transitionsToCurrent(from: .paid).isEmpty)
        #expect(await stateMachine.canTransition(to: .paid))
        #expect(await stateMachine.canTransition(to: .shipped) == false)
    }

    @Test func isAtEndingStateWhenNoTransitionsLeadFromTheCurrentState() async throws {
        let stateMachine = try makeStateMachine()
        #expect(await stateMachine.isAtEndingState == false)

        await stateMachine.process(.cancel)
        #expect(await stateMachine.isAtEndingState)
    }

    @Test func isAtInitialStateUntilFirstTransition() async throws {
        let stateMachine = try makeStateMachine()
        #expect(await stateMachine.isAtInitialState)

        // A rejected event is not a transition.
        await stateMachine.process(.ship)
        #expect(await stateMachine.isAtInitialState)

        // Adding an item leads back to the cart, but is a transition made.
        await stateMachine.process(.addItem)
        #expect(await stateMachine.state == .cart)
        #expect(await stateMachine.isAtInitialState == false)
    }

    // MARK: - Transition log

    @Test func logKeepsTheNewestTransitionsUpToItsCapacity() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions,
                                            initialState: .cart,
                                            logCapacity: 2)

        for event in [.checkOut, .pay, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        let log = await stateMachine.transitionLog
        #expect(log.count == 2)
        #expect(log.first == TransitionMade(from: .paid, event: .ship, to: .shipped))
        #expect(log.last == TransitionMade(from: .shipped, event: .deliver, to: .delivered))
        #expect(await stateMachine.stateChangeCount == 4, "The counters should not depend on the log.")
    }

    @Test func logIsIteratedFromOldestToNewestTransition() async throws {
        let stateMachine = try makeStateMachine()
        for event in [.checkOut, .pay, .ship] as [OrderEvent] {
            await stateMachine.process(event)
        }

        let log = await stateMachine.transitionLog
        #expect(log.map(\.event) == [.checkOut, .pay, .ship])
        #expect(log.map(\.to) == [.checkout, .paid, .shipped])
        #expect(await stateMachine.enteredWith == log.last)
    }

    @Test func logDoesNotKeepRejectedEvents() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.ship)
        await stateMachine.process(.checkOut)
        await stateMachine.process(.checkOut)

        let log = await stateMachine.transitionLog
        #expect(log.count == 1)
        #expect(await stateMachine.processedEventsCount == 3)
        #expect(await stateMachine.rejectedEventsCount == 2)
    }

    // MARK: - Entered with

    @Test func enteredWithIsNilUntilFirstTransition() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        #expect(await stateMachine.enteredWith == nil)

        // Rejected, as there is nothing to ship in the cart.
        await stateMachine.process(.ship)
        #expect(await stateMachine.enteredWith == nil)
    }

    @Test func enteredWithIsLastTransitionMade() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        await stateMachine.process(.checkOut)
        #expect(await stateMachine.enteredWith == TransitionMade(from: .cart, event: .checkOut, to: .checkout))

        await stateMachine.process(.pay)
        #expect(await stateMachine.enteredWith == TransitionMade(from: .checkout, event: .pay, to: .paid))

        // A rejected event does not change how the state was entered.
        await stateMachine.process(.checkOut)
        #expect(await stateMachine.enteredWith == TransitionMade(from: .checkout, event: .pay, to: .paid))
    }

    @Test(arguments: [0, 1, nil] as [UInt?])
    func enteredWithDoesNotDependOnTheLogCapacity(logCapacity: UInt?) async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions,
                                            initialState: .cart,
                                            logCapacity: logCapacity)
        await stateMachine.process(.checkOut)
        await stateMachine.process(.pay)

        #expect(await stateMachine.enteredWith == TransitionMade(from: .checkout, event: .pay, to: .paid))
    }
}
