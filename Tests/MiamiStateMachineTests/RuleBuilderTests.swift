import Testing
import MiamiStateMachine

/// Rules written state by state with the rule builder.
struct RuleBuilderTests {

    /// All the rules of a state machine.
    private func rules(of stateMachine: OrderStateMachine) -> Set<OrderTransition> {
        Set(stateMachine.states.flatMap { stateMachine.transitions(from: $0) })
    }

    // MARK: - The order fixture, built

    @TransitionRuleBuilder<OrderEvent, OrderState>
    private var builtFixture: Set<OrderTransition> {
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
        #expect(builtFixture == OrderFixture.transitions)
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
        @TransitionRuleBuilder<OrderEvent, OrderState>
        var built: Set<OrderTransition> {
            From(allExcept: [.cancelled, .delivered]) {
                On(.cancel, to: .cancelled)
                On(.editCart, to: .cart)
            }
        }

        #expect(built == OrderTransition.from(allExcept: [.cancelled, .delivered], event: .cancel, to: .cancelled)
            .union(OrderTransition.from(allExcept: [.cancelled, .delivered], event: .editCart, to: .cart)))
    }

    @Test func atEveryState() {
        @TransitionRuleBuilder<OrderEvent, OrderState>
        var built: Set<OrderTransition> {
            AtEveryState(.addItem)
        }

        #expect(built == OrderTransition.atEveryState(event: .addItem))
    }

    // MARK: - Mixed with code

    @Test func plainRulesAndSetsOfRules() {
        @TransitionRuleBuilder<OrderEvent, OrderState>
        var built: Set<OrderTransition> {
            OrderTransition(from: .cart, event: .checkOut, to: .checkout)
            OrderTransition.from(allExcept: [.cancelled], event: .cancel, to: .cancelled)
        }

        #expect(built == Set([OrderTransition(from: .cart, event: .checkOut, to: .checkout)])
            .union(OrderTransition.from(allExcept: [.cancelled], event: .cancel, to: .cancelled)))
    }

    @Test(arguments: [true, false])
    func conditions(express: Bool) {
        @TransitionRuleBuilder<OrderEvent, OrderState>
        var built: Set<OrderTransition> {
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
        #expect(built == (express ? [paid, delivered, invoice] : [paid, delivered]))
    }

    @Test func loops() {
        let states: [OrderState] = [.cart, .checkout, .paid]

        @TransitionRuleBuilder<OrderEvent, OrderState>
        var built: Set<OrderTransition> {
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

        #expect(built == [
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
