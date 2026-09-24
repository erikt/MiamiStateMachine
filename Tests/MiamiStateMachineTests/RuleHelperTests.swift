import Testing
import MiamiStateMachine

/// Rules for the same event from many states, made from the cases of the states.
struct RuleHelperTests {

    // MARK: - From every state but some

    @Test func ruleFromEveryStateButTheExcludedOnes() {
        let rules = OrderTransition.from(allExcept: [.cancelled, .delivered], event: .cancel, to: .cancelled)

        let expected = Set(OrderState.allCases
            .filter { $0 != .cancelled && $0 != .delivered }
            .map { OrderTransition(from: $0, event: .cancel, to: .cancelled) })
        #expect(rules == expected)
        #expect(rules.count == OrderState.allCases.count - 2)
    }

    @Test func withoutExclusionsTheStateLedToLeadsBackToItself() {
        let rules = OrderTransition.from(allExcept: [], event: .cancel, to: .cancelled)

        #expect(rules.count == OrderState.allCases.count)
        #expect(rules.contains(OrderTransition(from: .cancelled, event: .cancel, to: .cancelled)))
    }

    @Test func stateLedToAndExcludedStaysAnEndingState() async throws {
        let rules = Set([
            OrderTransition(from: .cart, event: .checkOut, to: .checkout),
            OrderTransition(from: .checkout, event: .pay, to: .paid),
        ])
        .union(OrderTransition.from(allExcept: [.cancelled], event: .cancel, to: .cancelled))
        let stateMachine = try StateMachine(transitions: rules, initialState: .cart)

        await stateMachine.process(.checkOut)
        await stateMachine.process(.pay)
        #expect(await stateMachine.process(.cancel) == TransitionEvent(from: .paid, event: .cancel, to: .cancelled))

        #expect(await stateMachine.isAtEndingState)
        #expect(stateMachine.endingStates == [.cancelled])
    }

    @Test func ruleInConflictWithAnotherRuleIsFound() throws {
        // Cancelling in the cart leads back to the cart, not to cancelled.
        let rules = Set([OrderTransition(from: .cart, event: .cancel, to: .cart)])
            .union(OrderTransition.from(allExcept: [.cancelled], event: .cancel, to: .cancelled))

        let error = try #require(throws: OrderStateMachine.DefinitionError.self) {
            try StateMachine(transitions: rules, initialState: .cart)
        }
        #expect(error.conflictingTransitions == [
            OrderTransition(from: .cart, event: .cancel, to: .cart),
            OrderTransition(from: .cart, event: .cancel, to: .cancelled),
        ])
    }

    // MARK: - At every state

    @Test func ruleAtEveryStateLeadsBackToItsState() {
        let rules = OrderTransition.atEveryState(event: .addItem)

        #expect(rules == Set(OrderState.allCases.map { OrderTransition(from: $0, event: .addItem, to: $0) }))
    }

    @Test func eventAtEveryStateIsAcceptedEverywhereAndChangesNothing() async throws {
        let rules = OrderFixture.transitions.union(OrderTransition.atEveryState(event: .shipExpress))
        let stateMachine = try StateMachine(transitions: rules, initialState: .cart)

        for event in [.shipExpress, .buyNow, .shipExpress, .cancel, .shipExpress] as [OrderEvent] {
            let before = await stateMachine.state
            let made = try #require(await stateMachine.process(event))
            if event == .shipExpress {
                #expect(made.to == before)
            }
        }

        #expect(await stateMachine.state == .cancelled)
        #expect(stateMachine.endingStates.isEmpty, "Every state has a rule leading back to itself.")
    }
}
