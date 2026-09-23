import Testing
import MiamiStateMachine

struct ShortestPathTests {
    let stateMachine: OrderStateMachine

    init() throws {
        stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
    }

    /// Verifies that a path is a connected way through a state machine, from
    /// a state to another state, only using transitions of the state machine.
    private func verify(_ path: [OrderTransition],
                        leadsFrom state: OrderState,
                        to newState: OrderState,
                        in stateMachine: OrderStateMachine,
                        sourceLocation: SourceLocation = #_sourceLocation)
    {
        #expect(path.first?.from == state, "Path should start from \(state).", sourceLocation: sourceLocation)
        #expect(path.last?.to == newState, "Path should lead to \(newState).", sourceLocation: sourceLocation)

        for (transition, next) in zip(path, path.dropFirst()) {
            #expect(transition.to == next.from,
                    "\(next) should continue from where \(transition) ended.",
                    sourceLocation: sourceLocation)
        }

        for transition in path {
            #expect(stateMachine.transition(from: transition.from, for: transition.event) == transition,
                    "\(transition) should be a transition of the state machine.",
                    sourceLocation: sourceLocation)
        }
    }

    /// The fewest events needed from a state to every state that can be reached
    /// from it. Found with a breadth-first search of the transitions, kept apart
    /// from the search of the state machine, to have something to compare with.
    private func fewestEvents(from state: OrderState, in stateMachine: OrderStateMachine) -> [OrderState: Int] {
        var counts = [state: 0]
        var reached = [state]

        while !reached.isEmpty {
            var reachedNext: [OrderState] = []
            for current in reached {
                for transition in stateMachine.transitions(from: current) where counts[transition.to] == nil {
                    counts[transition.to] = counts[current, default: 0] + 1
                    reachedNext.append(transition.to)
                }
            }
            reached = reachedNext
        }

        return counts
    }

    // MARK: - Path between states

    @Test(arguments: [
        (OrderState.cart, OrderState.checkout, [OrderEvent.checkOut]),
        (.checkout, .cart, [.editCart]),
        (.checkout, .paid, [.pay]),
        (.paid, .cancelled, [.cancel]),
        // Buy now is one event less than checking out and paying.
        (.cart, .paid, [.buyNow]),
        (.cart, .shipped, [.buyNow, .ship]),
        (.cart, .delivered, [.buyNow, .ship, .deliver]),
        // Going back to the cart, to buy now, is one event more than paying.
        (.checkout, .delivered, [.pay, .ship, .deliver]),
    ])
    func findsPathWithFewestEvents(from state: OrderState, to newState: OrderState, expectedEvents: [OrderEvent]) throws {
        let path = try #require(stateMachine.shortestPath(from: state, to: newState))

        #expect(path.map(\.event) == expectedEvents)
        verify(path, leadsFrom: state, to: newState, in: stateMachine)
    }

    @Test(arguments: OrderState.allCases)
    func pathToSameStateIsEmpty(state: OrderState) {
        // Also for the cart, where adding an item leads back to the cart,
        // and for the returned state, which is not part of any transition.
        #expect(stateMachine.shortestPath(from: state, to: state) == [])
    }

    @Test(arguments: [
        // Only reachable against the direction of the transitions.
        (OrderState.paid, OrderState.cart),
        (.delivered, .shipped),
        // Nothing leads from an ending state.
        (.cancelled, .delivered),
        (.delivered, .cancelled),
        // The returned state is not part of any transition.
        (.cart, .returned),
        (.returned, .cart),
    ])
    func unreachableStateHasNoPath(from state: OrderState, to newState: OrderState) {
        #expect(stateMachine.shortestPath(from: state, to: newState) == nil)
    }

    @Test(arguments: OrderState.allCases, OrderState.allCases)
    func processingEventsOfPathLeadsToState(from state: OrderState, to newState: OrderState) async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: state)

        let path = stateMachine.shortestPath(from: state, to: newState)
        let fewestEvents = fewestEvents(from: state, in: stateMachine)[newState]
        #expect(path?.count == fewestEvents, "Both should be nil if there is no way to the new state.")

        guard let path else {
            // Nothing to process if there is no way to the new state.
            return
        }

        for transition in path {
            await stateMachine.process(transition.event)
        }

        #expect(await stateMachine.state == newState)
        #expect(await stateMachine.stateChangeCount == path.count, "Every event should lead to a state change.")
        #expect(await stateMachine.rejectedEventsCount == 0)
    }

    // MARK: - More than one shortest path

    @Test func usesOneOfTheEventsConnectingTheSameStates() throws {
        let transitions = OrderFixture.transitions.union([
            TransitionRule(from: .paid, event: .shipExpress, to: .shipped),
        ])
        let stateMachine = try StateMachine(transitions: transitions, initialState: .cart)

        let path = try #require(stateMachine.shortestPath(from: .cart, to: .delivered))

        #expect(path.map(\.to) == [.paid, .shipped, .delivered])
        #expect([.ship, .shipExpress].contains(path[1].event))
        verify(path, leadsFrom: .cart, to: .delivered, in: stateMachine)
    }

    @Test func findsOneOfTheShortestPaths() throws {
        // Buying now and shipping are two events from the cart to shipped. So
        // are checking out and shipping on invoice, but by way of other states.
        let transitions = OrderFixture.transitions.union([
            TransitionRule(from: .checkout, event: .shipOnInvoice, to: .shipped),
        ])
        let stateMachine = try StateMachine(transitions: transitions, initialState: .cart)

        let path = try #require(stateMachine.shortestPath(from: .cart, to: .shipped))

        #expect(path.count == 2)
        verify(path, leadsFrom: .cart, to: .shipped, in: stateMachine)
    }

    // MARK: - State machine without transitions

    @Test func stateMachineWithoutTransitionsHasNoPaths() throws {
        let stateMachine = try OrderStateMachine(transitions: [], initialState: .cart)

        #expect(stateMachine.shortestPath(from: .cart, to: .paid) == nil)
        #expect(stateMachine.shortestPath(from: .cart, to: .cart) == [])
    }

    // MARK: - Path from current state

    @Test func pathFromCurrentStateFollowsTheStateMachine() async {
        #expect(await stateMachine.shortestPath(to: .delivered)?.map(\.event) == [.buyNow, .ship, .deliver])
        #expect(await stateMachine.shortestPath(to: .cart) == [])

        await stateMachine.process(.checkOut)
        #expect(await stateMachine.shortestPath(to: .delivered)?.map(\.event) == [.pay, .ship, .deliver])
        #expect(await stateMachine.shortestPath(to: .cart)?.map(\.event) == [.editCart])

        await stateMachine.process(.cancel)
        #expect(await stateMachine.shortestPath(to: .delivered) == nil)
        #expect(await stateMachine.shortestPath(to: .cancelled) == [])
    }
}
