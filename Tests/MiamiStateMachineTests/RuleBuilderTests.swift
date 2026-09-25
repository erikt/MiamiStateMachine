import Testing
import MiamiStateMachine

/// Rules of the order fixture as the rule builder writes them, without a context.
private typealias OrderRules = TransitionRules<OrderEvent, OrderState, Void>

/// Rules written state by state with the rule builder.
struct RuleBuilderTests {

    /// All the rules of a state machine.
    private func rules(of stateMachine: OrderStateMachine) -> Set<OrderTransition> {
        Set(stateMachine.states.flatMap { stateMachine.transitions(from: $0) })
    }

    // MARK: - The order fixture, built

    @TransitionRuleBuilder<OrderEvent, OrderState, Void>
    private var builtFixture: OrderRules {
        From(.cart) {
            On(.addItem, to: .cart)
            On(.checkOut, to: .checkout)
            On(.buyNow, to: .paid)
            On(.cancel, to: .cancelled)
        }
        From(.checkout) {
            On(.editCart, to: .cart)
            On(.pay, to: .paid)
            On(.cancel, to: .cancelled)
        }
        From(.paid) {
            On(.ship, to: .shipped)
            On(.cancel, to: .cancelled)
        }
        From(.shipped) {
            On(.deliver, to: .delivered)
        }
    }

    @Test func builtRulesAreTheRulesWrittenOut() {
        #expect(builtFixture.rules == OrderFixture.transitions)
    }

    @Test func stateMachineIsCreatedFromBuiltRules() async throws {
        let stateMachine = try OrderStateMachine(initialState: .cart) {
            From(.cart) {
                On(.checkOut, to: .checkout)
            }
            From(.checkout) {
                On(.pay, to: .paid)
            }
        }

        #expect(stateMachine.initialState == .cart)
        #expect(rules(of: stateMachine) == [
            OrderTransition(from: .cart, event: .checkOut, to: .checkout),
            OrderTransition(from: .checkout, event: .pay, to: .paid),
        ])
        #expect(await stateMachine.process(.checkOut)?.to == .checkout)
    }

    @Test func logCapacityIsGivenToTheStateMachine() async throws {
        let stateMachine = try OrderStateMachine(initialState: .cart, logCapacity: 1) {
            From(.cart) {
                On(.addItem, to: .cart)
            }
        }

        await stateMachine.process(.addItem)
        await stateMachine.process(.addItem)

        #expect(await stateMachine.transitionLog.count == 1)
    }

    // MARK: - Many states

    @Test func fromEveryStateButSome() {
        @TransitionRuleBuilder<OrderEvent, OrderState, Void>
        var built: OrderRules {
            From(allExcept: [.cancelled, .delivered]) {
                On(.cancel, to: .cancelled)
                On(.editCart, to: .cart)
            }
        }

        #expect(built.rules == OrderTransition.from(allExcept: [.cancelled, .delivered], event: .cancel, to: .cancelled)
            .union(OrderTransition.from(allExcept: [.cancelled, .delivered], event: .editCart, to: .cart)))
    }

    @Test func atEveryState() {
        @TransitionRuleBuilder<OrderEvent, OrderState, Void>
        var built: OrderRules {
            AtEveryState(.addItem)
        }

        #expect(built.rules == OrderTransition.atEveryState(event: .addItem))
    }

    // MARK: - Mixed with code

    @Test func plainRulesAndSetsOfRules() {
        @TransitionRuleBuilder<OrderEvent, OrderState, Void>
        var built: OrderRules {
            OrderTransition(from: .cart, event: .checkOut, to: .checkout)
            OrderTransition.from(allExcept: [.cancelled], event: .cancel, to: .cancelled)
        }

        #expect(built.rules == Set([OrderTransition(from: .cart, event: .checkOut, to: .checkout)])
            .union(OrderTransition.from(allExcept: [.cancelled], event: .cancel, to: .cancelled)))
    }

    @Test(arguments: [true, false])
    func conditions(express: Bool) {
        @TransitionRuleBuilder<OrderEvent, OrderState, Void>
        var built: OrderRules {
            if express {
                From(.paid) {
                    On(.shipExpress, to: .shipped)
                }
            } else {
                From(.paid) {
                    On(.ship, to: .shipped)
                }
            }
            From(.shipped) {
                On(.deliver, to: .delivered)
                if express {
                    On(.shipOnInvoice, to: .shipped)
                }
            }
        }

        let paid = OrderTransition(from: .paid, event: express ? .shipExpress : .ship, to: .shipped)
        let delivered = OrderTransition(from: .shipped, event: .deliver, to: .delivered)
        let invoice = OrderTransition(from: .shipped, event: .shipOnInvoice, to: .shipped)
        #expect(built.rules == (express ? [paid, delivered, invoice] : [paid, delivered]))
    }

    @Test func loops() {
        let states: [OrderState] = [.cart, .checkout, .paid]

        @TransitionRuleBuilder<OrderEvent, OrderState, Void>
        var built: OrderRules {
            for state in states {
                From(state) {
                    On(.cancel, to: .cancelled)
                }
            }
            From(.shipped) {
                for event in [OrderEvent.deliver, .shipExpress] {
                    On(event, to: .delivered)
                }
            }
        }

        #expect(built.rules == [
            OrderTransition(from: .cart, event: .cancel, to: .cancelled),
            OrderTransition(from: .checkout, event: .cancel, to: .cancelled),
            OrderTransition(from: .paid, event: .cancel, to: .cancelled),
            OrderTransition(from: .shipped, event: .deliver, to: .delivered),
            OrderTransition(from: .shipped, event: .shipExpress, to: .delivered),
        ])
    }

    @Test func emptyBuilderHasNoRules() throws {
        let stateMachine = try OrderStateMachine(initialState: .cart) {}

        #expect(stateMachine.transitionCount == 0)
        #expect(stateMachine.isEndingState(.cart))
    }

    // MARK: - Consistency

    @Test func conflictingRulesAreFoundWhenCreated() throws {
        let error = try #require(throws: OrderStateMachine.DefinitionError.self) {
            try OrderStateMachine(initialState: .cart) {
                From(.cart) {
                    On(.cancel, to: .cancelled)
                }
                From(allExcept: [.cancelled]) {
                    On(.cancel, to: .cart)
                }
            }
        }

        #expect(error.conflictingTransitions == [
            OrderTransition(from: .cart, event: .cancel, to: .cancelled),
            OrderTransition(from: .cart, event: .cancel, to: .cart),
        ])
    }

    @Test func sameRuleWrittenTwiceIsOneRule() throws {
        let stateMachine = try OrderStateMachine(initialState: .cart) {
            From(.cart) {
                On(.checkOut, to: .checkout)
                On(.checkOut, to: .checkout)
            }
            OrderTransition(from: .cart, event: .checkOut, to: .checkout)
        }

        #expect(stateMachine.transitionCount == 1)
    }
}

/// The builder can be used on the main actor. A closure written there is
/// isolated to the main actor, unless it is `Sendable`, and could then not be
/// given to the state machine: this did not compile before the fix.
@MainActor
struct RuleBuilderOnTheMainActorTests {
    var offersExpress = true

    @Test func stateMachineIsCreatedOnTheMainActor() throws {
        let stateMachine = try OrderStateMachine(initialState: .cart) {
            From(.cart) {
                On(.checkOut, to: .checkout)
                if offersExpress {
                    On(.buyNow, to: .paid)
                }
            }
        }

        #expect(stateMachine.transitionCount == 2)
    }
}
