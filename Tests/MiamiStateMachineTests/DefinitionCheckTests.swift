import Testing
import MiamiStateMachine

struct DefinitionCheckTests {

    /// The state machine of an order, with more transitions if needed.
    private func makeStateMachine(initialState: OrderState = .cart,
                                  adding transitions: Set<OrderTransition> = []) throws -> OrderStateMachine
    {
        try StateMachine(transitions: OrderFixture.transitions.union(transitions), initialState: initialState)
    }

    // MARK: - States

    @Test func statesAreTheInitialStateAndTheStatesOfTheTransitions() throws {
        // Returned is not part of any transition.
        #expect(try makeStateMachine().states == [.cart, .checkout, .paid, .shipped, .delivered, .cancelled])
        #expect(try makeStateMachine(initialState: .returned).states.contains(.returned))
        #expect(try OrderStateMachine(transitions: [], initialState: .cart).states == [.cart])
    }

    @Test func initialStateIsReadWithoutWaitingForTheStateMachine() throws {
        // Not an asynchronous test, so this would not compile otherwise.
        #expect(try makeStateMachine(initialState: .paid).initialState == .paid)
    }

    @Test func endingStatesHaveNoTransitionsLeadingFromThem() throws {
        #expect(try makeStateMachine().endingStates == [.delivered, .cancelled])
        #expect(try makeStateMachine(initialState: .returned).endingStates == [.delivered, .cancelled, .returned])
        #expect(try OrderStateMachine(transitions: [], initialState: .cart).endingStates == [.cart])
    }

    // MARK: - Reachable states

    /// The states reachable from every state of the order.
    static let reachableStates: [(OrderState, Set<OrderState>)] = [
        (.cart, [.cart, .checkout, .paid, .shipped, .delivered, .cancelled]),
        // The checkout leads back to the cart.
        (.checkout, [.cart, .checkout, .paid, .shipped, .delivered, .cancelled]),
        (.paid, [.paid, .shipped, .delivered, .cancelled]),
        (.shipped, [.shipped, .delivered]),
        (.delivered, [.delivered]),
        (.cancelled, [.cancelled]),
        // Not part of any transition.
        (.returned, [.returned]),
    ]

    @Test(arguments: reachableStates)
    func reachableStatesAreTheStateAndAllStatesAfterIt(state: OrderState, reachable: Set<OrderState>) throws {
        #expect(try makeStateMachine().reachableStates(from: state) == reachable)
    }

    @Test(arguments: OrderState.allCases, OrderState.allCases)
    func stateIsReachableExactlyWhenThereIsAShortestPath(from state: OrderState, to newState: OrderState) throws {
        let stateMachine = try makeStateMachine()

        let isReachable = stateMachine.reachableStates(from: state).contains(newState)
        let hasPath = stateMachine.shortestPath(from: state, to: newState) != nil
        #expect(isReachable == hasPath)
    }

    @Test func reachableStatesFromCurrentFollowTheStateMachine() async throws {
        let stateMachine = try makeStateMachine()
        #expect(await stateMachine.reachableStatesFromCurrent.count == 6)

        await stateMachine.process(.buyNow)
        #expect(await stateMachine.reachableStatesFromCurrent == [.paid, .shipped, .delivered, .cancelled])

        await stateMachine.process(.cancel)
        #expect(await stateMachine.reachableStatesFromCurrent == [.cancelled])
    }

    // MARK: - Unreachable states

    @Test func everyStateOfTheOrderIsReachableFromTheCart() throws {
        #expect(try makeStateMachine().unreachableStates.isEmpty)
    }

    @Test func statesOnlyLeadingToTheInitialStateAreUnreachable() throws {
        // Nothing leads back from paid to the cart or the checkout.
        #expect(try makeStateMachine(initialState: .paid).unreachableStates == [.cart, .checkout])
    }

    @Test func stateNothingLeadsToIsUnreachable() throws {
        // A returned order can be paid again, but the transition
        // returning an order is forgotten.
        let stateMachine = try makeStateMachine(adding: [
            TransitionRule(from: .returned, event: .pay, to: .paid),
        ])

        #expect(stateMachine.states.contains(.returned))
        #expect(stateMachine.unreachableStates == [.returned])
    }

    @Test func initialStateIsNeverUnreachable() throws {
        #expect(try makeStateMachine(initialState: .returned).unreachableStates.contains(.returned) == false)
        #expect(try OrderStateMachine(transitions: [], initialState: .cart).unreachableStates.isEmpty)
    }

    // MARK: - States without path to ending state

    @Test func everyStateOfTheOrderHasAPathToAnEndingState() throws {
        #expect(try makeStateMachine().statesWithoutPathToEndingState.isEmpty)
    }

    @Test func stateOnlyLeadingBackToItselfHasNoPathToAnEndingState() throws {
        // A paid order can be returned, but a returned order can only be edited.
        let stateMachine = try makeStateMachine(adding: [
            TransitionRule(from: .paid, event: .editCart, to: .returned),
            TransitionRule(from: .returned, event: .editCart, to: .returned),
        ])

        // Paid still leads to shipped, so only returned is without a path.
        #expect(stateMachine.statesWithoutPathToEndingState == [.returned])
    }

    @Test func statesLeadingAroundWithoutWayOutHaveNoPathToAnEndingState() throws {
        let stateMachine = try StateMachine(transitions: [
            // The cart and the checkout lead to each other, and nowhere else.
            OrderTransition(from: .cart, event: .checkOut, to: .checkout),
            OrderTransition(from: .checkout, event: .editCart, to: .cart),
            // Paid leads to an ending state, but nothing leads to paid.
            OrderTransition(from: .paid, event: .ship, to: .shipped),
        ], initialState: .cart)

        #expect(stateMachine.endingStates == [.shipped])
        #expect(stateMachine.statesWithoutPathToEndingState == [.cart, .checkout])
        #expect(stateMachine.unreachableStates == [.paid, .shipped])
    }

    @Test func noStateHasAPathToAnEndingStateWithoutEndingStates() throws {
        let stateMachine = try StateMachine(transitions: [
            OrderTransition(from: .cart, event: .checkOut, to: .checkout),
            OrderTransition(from: .checkout, event: .editCart, to: .cart),
        ], initialState: .cart)

        #expect(stateMachine.endingStates.isEmpty)
        #expect(stateMachine.statesWithoutPathToEndingState == [.cart, .checkout])
    }

    @Test func initialStateWithoutTransitionsIsItsOwnEndingState() throws {
        #expect(try makeStateMachine(initialState: .returned).statesWithoutPathToEndingState.isEmpty)
    }

    // MARK: - Cycles

    @Test func statesLeadingToEachOtherAreACycle() throws {
        // The cart and the checkout of the order.
        #expect(try makeStateMachine().hasCycle)
    }

    @Test func transitionBackToTheSameStateIsACycle() throws {
        let stateMachine = try StateMachine(transitions: [
            OrderTransition(from: .cart, event: .addItem, to: .cart),
            OrderTransition(from: .cart, event: .buyNow, to: .paid),
        ], initialState: .cart)

        #expect(stateMachine.hasCycle)
    }

    @Test func twoWaysToTheSameStateAreNotACycle() throws {
        let stateMachine = try StateMachine(transitions: [
            OrderTransition(from: .cart, event: .checkOut, to: .checkout),
            OrderTransition(from: .checkout, event: .pay, to: .paid),
            OrderTransition(from: .cart, event: .buyNow, to: .paid),
            OrderTransition(from: .paid, event: .ship, to: .shipped),
        ], initialState: .cart)

        #expect(stateMachine.hasCycle == false)
    }

    @Test func cycleAmongUnreachableStatesCounts() throws {
        let stateMachine = try StateMachine(transitions: [
            OrderTransition(from: .cart, event: .buyNow, to: .paid),
            // Nothing leads here from the cart.
            OrderTransition(from: .shipped, event: .editCart, to: .returned),
            OrderTransition(from: .returned, event: .ship, to: .shipped),
        ], initialState: .cart)

        #expect(stateMachine.unreachableStates == [.shipped, .returned])
        #expect(stateMachine.hasCycle)
    }

    @Test func stateMachineWithoutTransitionsHasNoCycle() throws {
        #expect(try OrderStateMachine(transitions: [], initialState: .cart).hasCycle == false)
    }

    // MARK: - Definitions made at random

    /// Every check is compared with a slower and more obvious way to the same
    /// answer, asking for the reachable states of one state at a time.
    @Test(arguments: [1, 2, 3, 4, 5] as [UInt64])
    func checksAgreeWithReachabilityOfOneStateAtATime(seed: UInt64) throws {
        var generator = SeededGenerator(seed: seed)

        for _ in 0 ..< 40 {
            // Few states and events, to get cycles, several events
            // between states, and states out of reach.
            let stateCount = Int.random(in: 1 ... 12, using: &generator)
            var transitions: Set<TransitionRule<Int, Int>> = []
            for state in 0 ..< stateCount {
                for event in 0 ..< 3 where Int.random(in: 0 ..< 3, using: &generator) == 0 {
                    // One transition at most for a state and an event, to be consistent.
                    let newState = Int.random(in: 0 ..< stateCount, using: &generator)
                    transitions.insert(TransitionRule(from: state, event: event, to: newState))
                }
            }

            let stateMachine = try StateMachine(transitions: transitions, initialState: 0)
            let states = stateMachine.states
            let reachable = Dictionary(uniqueKeysWithValues: states.map { ($0, stateMachine.reachableStates(from: $0)) })

            // Reachable is the same as having a shortest path.
            for (state, reachableStates) in reachable {
                let statesWithPath = states.filter { stateMachine.shortestPath(from: state, to: $0) != nil }
                try #require(reachableStates == statesWithPath, "From \(state) in \(transitions)")
            }

            try #require(stateMachine.unreachableStates == states.subtracting(reachable[0] ?? []),
                         "Unreachable in \(transitions)")

            let endingStates = stateMachine.endingStates
            try #require(endingStates == states.filter { stateMachine.transitions(from: $0).isEmpty })

            let withoutPath = states.filter { reachable[$0]?.isDisjoint(with: endingStates) ?? true }
            try #require(stateMachine.statesWithoutPathToEndingState == withoutPath,
                         "Without path to an ending state in \(transitions)")

            // A cycle is a transition to a state leading back to where the transition started.
            let hasCycle = transitions.contains { reachable[$0.to]?.contains($0.from) ?? false }
            try #require(stateMachine.hasCycle == hasCycle, "Cycle in \(transitions)")
        }
    }
}
