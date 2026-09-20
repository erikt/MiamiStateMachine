import Testing
import MiamiStateMachine

struct StateMachineTests {

    private func makeStateMachine(initialState: OrderState = .cart) throws -> OrderStateMachine {
        try #require(StateMachine(transitions: OrderFixture.transitions, initialState: initialState))
    }

    // MARK: - Definition

    @Test func knowsItsTransitions() throws {
        let stateMachine = try makeStateMachine()

        #expect(stateMachine.numOfTransitions == 10)
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
        let stateMachine = try #require(StateMachine(transitions: [
            StateTransition(from: OrderState.cart, event: OrderEvent.addItem, to: .cart),
        ], initialState: .cart))

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
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions,
                                                     initialState: .cart,
                                                     logCapacity: 2))

        for event in [.checkOut, .pay, .ship, .deliver] as [OrderEvent] {
            await stateMachine.process(event)
        }

        let log = await stateMachine.transitionLog
        #expect(log.count == 2)
        #expect(log.peekOldest == StateTransition(from: .paid, event: .ship, to: .shipped))
        #expect(log.peek == StateTransition(from: .shipped, event: .deliver, to: .delivered))
        #expect(await stateMachine.stateChangeCount == 4, "The counters should not depend on the log.")
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
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions, initialState: .cart))
        #expect(await stateMachine.enteredWith == nil)

        // Rejected, as there is nothing to ship in the cart.
        await stateMachine.process(.ship)
        #expect(await stateMachine.enteredWith == nil)
    }

    @Test func enteredWithIsLastTransitionMade() async throws {
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions, initialState: .cart))

        await stateMachine.process(.checkOut)
        #expect(await stateMachine.enteredWith == StateTransition(from: .cart, event: .checkOut, to: .checkout))

        await stateMachine.process(.pay)
        #expect(await stateMachine.enteredWith == StateTransition(from: .checkout, event: .pay, to: .paid))

        // A rejected event does not change how the state was entered.
        await stateMachine.process(.checkOut)
        #expect(await stateMachine.enteredWith == StateTransition(from: .checkout, event: .pay, to: .paid))
    }

    @Test(arguments: [0, 1, nil] as [UInt?])
    func enteredWithDoesNotDependOnTheLogCapacity(logCapacity: UInt?) async throws {
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions,
                                                     initialState: .cart,
                                                     logCapacity: logCapacity))
        await stateMachine.process(.checkOut)
        await stateMachine.process(.pay)

        #expect(await stateMachine.enteredWith == StateTransition(from: .checkout, event: .pay, to: .paid))
    }
}
