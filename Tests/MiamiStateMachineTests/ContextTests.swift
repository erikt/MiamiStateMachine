import Testing
import MiamiStateMachine

/// A context changed by the actions of the transitions. A stream not working
/// shows as a consumer waiting forever, so the time limit makes it fail.
@Suite(.timeLimit(.minutes(1)))
struct ContextTests {

    // MARK: - Fixture

    enum CoinState: CaseIterable {
        case idle, hasCredit, outOfOrder
    }

    /// Inserting a coin carries its value.
    enum CoinEvent: StateMachineEvent {
        case insert(cents: Int)
        case cancel, breakDown, repair, service

        enum EventTrigger {
            case insert, cancel, breakDown, repair, service
        }

        var eventTrigger: EventTrigger {
            switch self {
            case .insert: .insert
            case .cancel: .cancel
            case .breakDown: .breakDown
            case .repair: .repair
            case .service: .service
            }
        }
    }

    /// What the states alone do not tell: the credit, and how often the machine was serviced.
    struct Credit: Equatable {
        var cents = 0
        var services = 0
    }

    typealias CoinMachine = StateMachine<CoinEvent, CoinState, Credit>
    typealias CoinRules = TransitionRules<CoinEvent, CoinState, Credit>

    /// Adds the value of an inserted coin to the credit.
    private static let addCoin: TransitionAction<CoinEvent, CoinState, Credit> = { credit, transition in
        if case .insert(let cents) = transition.event {
            credit.cents += cents
        }
    }

    @TransitionRuleBuilder<CoinEvent, CoinState, Credit>
    static var rules: CoinRules {
        From(.idle) {
            On(.insert, to: .hasCredit, action: addCoin)
        }
        From(.hasCredit) {
            On(.insert, to: .hasCredit, action: addCoin)
            On(.cancel, to: .idle) { credit, _ in
                credit.cents = 0
            }
        }
        From(allExcept: [.outOfOrder]) {
            // The credit is lost when the machine breaks down.
            On(.breakDown, to: .outOfOrder) { credit, _ in
                credit.cents = 0
            }
        }
        From(.outOfOrder) {
            On(.repair, to: .idle)
        }
        AtEveryState(.service) { credit, _ in
            credit.services += 1
        }
    }

    private func makeMachine(credit: Credit = Credit()) throws -> CoinMachine {
        try CoinMachine(initialState: .idle, context: credit) {
            Self.rules
        }
    }

    // MARK: - The context

    @Test func contextIsTheOneGiven() async throws {
        let machine = try makeMachine(credit: Credit(cents: 5, services: 2))

        #expect(await machine.context == Credit(cents: 5, services: 2))
    }

    @Test func actionsChangeTheContextWithWhatTheEventCarries() async throws {
        let machine = try makeMachine()

        await machine.process(.insert(cents: 25))
        await machine.process(.insert(cents: 100))

        #expect(await machine.context.cents == 125)
        #expect(await machine.state == .hasCredit)

        await machine.process(.cancel)

        #expect(await machine.context.cents == 0)
        #expect(await machine.state == .idle)
    }

    @Test func transitionWithoutAnActionLeavesTheContext() async throws {
        let machine = try makeMachine()
        await machine.process(.breakDown)

        await machine.process(.repair)

        #expect(await machine.context == Credit())
        #expect(await machine.state == .idle)
    }

    @Test func rejectedEventLeavesTheContext() async throws {
        let machine = try makeMachine()
        await machine.process(.insert(cents: 10))

        // Repairing a machine that works is rejected.
        #expect(await machine.process(.repair) == nil)

        #expect(await machine.context.cents == 10)
    }

    @Test func actionFromEveryStateButSome() async throws {
        for state in [CoinState.idle, .hasCredit] {
            let machine = try makeMachine(credit: Credit(cents: 50))
            if state == .hasCredit {
                await machine.process(.insert(cents: 5))
            }

            await machine.process(.breakDown)

            #expect(await machine.context.cents == 0, "Broken down from \(state).")
        }
    }

    @Test func actionAtEveryState() async throws {
        let machine = try makeMachine()

        await machine.process(.service)
        await machine.process(.insert(cents: 5))
        await machine.process(.service)
        await machine.process(.breakDown)
        await machine.process(.service)

        #expect(await machine.context == Credit(cents: 0, services: 3))
        #expect(await machine.state == .outOfOrder)
    }

    // MARK: - The rules

    @Test func actionsDoNotChangeTheRules() throws {
        let machine = try makeMachine()
        let plain = try CoinMachine(transitions: Self.rules.rules, initialState: .idle, context: Credit())

        #expect(machine.transitionCount == plain.transitionCount)
        #expect(Set(machine.states.flatMap { machine.transitions(from: $0) }) == Self.rules.rules)
    }

    @Test func ruleWrittenTwiceRunsBothActionsInOrder() async throws {
        let machine = try StateMachine<CoinEvent, CoinState, [String]>(initialState: .idle, context: []) {
            From(.idle) {
                On(.service, to: .idle) { log, _ in log.append("first") }
            }
            From(.idle) {
                On(.service, to: .idle) { log, _ in log.append("second") }
            }
        }

        await machine.process(.service)

        #expect(machine.transitionCount == 1)
        #expect(await machine.context == ["first", "second"])
    }

    @Test func transitionsGivenAsASetKeepTheContext() async throws {
        let machine = try CoinMachine(transitions: Self.rules.rules, initialState: .idle, context: Credit(cents: 7))

        await machine.process(.insert(cents: 5))

        #expect(await machine.context.cents == 7, "Rules given as a set have no actions.")
        #expect(await machine.state == .hasCredit)
    }

    @Test func conflictingRulesWithActionsAreFound() throws {
        #expect(throws: CoinMachine.DefinitionError.self) {
            try CoinMachine(initialState: .idle, context: Credit()) {
                From(.idle) {
                    On(.insert, to: .hasCredit, action: Self.addCoin)
                    On(.insert, to: .idle, action: Self.addCoin)
                }
            }
        }
    }

    // MARK: - The streams

    @Test func streamsDeliverTransitionsAfterTheirActions() async throws {
        let machine = try makeMachine()
        let transitions = await machine.transitionStream()

        await machine.process(.insert(cents: 25))
        await machine.process(.insert(cents: 10))
        await machine.process(.breakDown)

        // Out of order is no ending state, so the stream goes on: read three.
        var events: [CoinEvent.EventTrigger] = []
        for await transition in transitions.prefix(3) {
            events.append(transition.event.eventTrigger)
        }
        #expect(events == [.insert, .insert, .breakDown])
        #expect(await machine.context.cents == 0)
    }
}
