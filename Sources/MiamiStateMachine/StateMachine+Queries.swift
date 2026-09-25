// MARK: - About the current state

extension StateMachine {

    // These are the isolated twins of the questions about the definition
    // below, asked about the current state.

    /// All event triggers accepted at the current state, which are
    /// the ones leading to a state change from it.
    public var eventsFromCurrent: Set<Event.EventTrigger> {
        return events(from: state)
    }
    
    /// All event triggers leading (incoming) to the current state.
    public var eventsToCurrent: Set<Event.EventTrigger> {
        return events(to: state)
    }
    
    /// All possible outgoing transitions from the current state.
    public var transitionsFromCurrent: Set<TransitionRule<Event.EventTrigger, State>> {
        return transitions(from: state)
    }
    
    /// All possible incoming transition leading to the current state.
    public var transitionsToCurrent: Set<TransitionRule<Event.EventTrigger, State>> {
        return transitions(to: state)
    }

    /// All states that can still be reached from the current state, by
    /// processing no event, one event or several. The current state
    /// is always one of them.
    public var reachableStatesFromCurrent: Set<State> {
        return reachableStates(from: state)
    }

    /// If the state machine can transition to a state from the current state.
    /// - Parameter newState: State to check if it's possible to transition to.
    /// - Returns: If transition is possible.
    public func canTransition(to newState: State) -> Bool {
        return canTransition(from: self.state, to: newState)
    }
    
    /// All possible transitions from the current state, to another state.
    /// - Parameter newState: State to go to from the current state.
    /// - Returns: All possible transitions from the current state to another state.
    public func transitionsFromCurrent(to newState: State) -> Set<TransitionRule<Event.EventTrigger, State>> {
        return transitions(from: self.state, to: newState)
    }
    
    /// All possible transitions to the current state, from another state.
    /// - Parameter oldState: From state
    /// - Returns: All possible transitions from a state to the current state.
    public func transitionsToCurrent(from oldState: State) -> Set<TransitionRule<Event.EventTrigger, State>> {
        return transitions(from: oldState, to: self.state)
    }

    /// The shortest path from the current state to another state. This is
    /// the way to the state needing the fewest events.
    ///
    /// If there is more than one shortest path, one of them is returned.
    /// - Parameter newState: State to go to from the current state.
    /// - Returns: The transitions to make, in order, to get from the current
    /// state to the new state. If the new state cannot be reached from the
    /// current state, it returns nil. The path is empty if the new state is
    /// the current state.
    public func shortestPath(to newState: State) -> [TransitionRule<Event.EventTrigger, State>]? {
        return shortestPath(from: self.state, to: newState)
    }
}

// MARK: - Non-isolated

extension StateMachine {
    
    // These are nonisolated, mostly convenience methods and
    // computed properties. All of them are only interacting
    // with constant properties not in need of state isolation
    // to be safe.
    
    /// Total number of transitions defining the state machine. The number of
    /// transitions made by the state machine is `stateChangeCount`.
    public nonisolated var transitionCount: Int {
        return definition.ruleCount
    }
    
    /// The transition from a state for an event trigger. If the state
    /// has no transition for it, it returns nil. For an event, ask
    /// with `event.eventTrigger`.
    /// - Parameters:
    ///   - state: From state.
    ///   - event: Event.
    /// - Returns: Transition if there is one for the event at state.
    public nonisolated func transition(from state: State, for event: Event.EventTrigger) -> TransitionRule<Event.EventTrigger, State>? {
        return definition.rule(from: state, for: event)
    }
    
    /// All transitions leading to a state for a specific event trigger.
    /// - Parameters:
    ///   - state: To state.
    ///   - event: Event.
    /// - Returns: All transitions leading to state for an event.
    public nonisolated func transitions(to state: State, for event: Event.EventTrigger) -> Set<TransitionRule<Event.EventTrigger, State>> {
        return definition.rules(to: state).filter {
            $0.event == event
        }
    }
    
    /// All possible transitions from a state to another state.
    /// - Parameters:
    ///   - state: Starting state.
    ///   - newState: New state to transition to.
    /// - Returns: All possible transitions to the new state.
    public nonisolated func transitions(from state: State, to newState: State) -> Set<TransitionRule<Event.EventTrigger, State>> {
        return transitions(from: state).filter {
            $0.to == newState
        }
    }
    
    /// All possible transitions from a state.
    /// - Parameter state: State to start from.
    /// - Returns: All possible transitions from state.
    public nonisolated func transitions(from state: State) -> Set<TransitionRule<Event.EventTrigger, State>> {
        return definition.rules(from: state)
    }
    
    /// All transitions leading to a state.
    /// - Parameter state: State to go to.
    /// - Returns: All possible transitions to a state.
    public nonisolated func transitions(to state: State) -> Set<TransitionRule<Event.EventTrigger, State>> {
        return definition.rules(to: state)
    }

    /// All event triggers handled at a state.
    /// - Parameter state: State.
    /// - Returns: All event triggers going out from this state.
    public nonisolated func events(from state: State) -> Set<Event.EventTrigger> {
        return definition.events(from: state)
    }
    
    /// All event triggers leading to a state.
    /// Please note, the same event trigger could be handled at different
    /// states, all leading to the same state.
    /// - Parameter state: State.
    /// - Returns: All events leading to this state.
    public nonisolated func events(to state: State) -> Set<Event.EventTrigger> {
        return Set(definition.rules(to: state).map(\.event))
    }
    
    /// All event triggers defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    public nonisolated func events(from: State, to: State) -> Set<Event.EventTrigger> {
        return Set<Event.EventTrigger>(transitions(from: from, to: to).map {
            $0.event
        })
    }
    
    /// If it is possible to transition from a state to another state.
    /// - Parameters:
    ///   - state: State to transition from.
    ///   - newState: State to transition to.
    /// - Returns: If transition is possible.
    public nonisolated func canTransition(from state: State, to newState: State) -> Bool {
        return !transitions(from: state, to: newState).isEmpty
    }

    /// The shortest path from a state to another state. This is the way
    /// between the states needing the fewest events.
    ///
    /// Processing an event with the trigger of each transition in the path, in
    /// order, takes a state machine that is in `state` to `newState`. An
    /// event without anything to carry is its own trigger, and can be processed
    /// as it is in the path.
    ///
    /// If there is more than one shortest path, one of them is returned.
    /// Which one is unspecified, but repeated calls on the same state
    /// machine instance return the same path.
    /// - Parameters:
    ///   - state: State to start from.
    ///   - newState: State to go to.
    /// - Returns: The transitions to make, in order, to get from the state to
    /// the new state. If the new state cannot be reached from the state,
    /// it returns nil. The path is empty if the two states are the same.
    public nonisolated func shortestPath(from state: State, to newState: State) -> [TransitionRule<Event.EventTrigger, State>]? {
        return definition.graph.shortestPath(from: state, to: newState)
    }
    
    /// If a state is an ending state. No transitions lead from an ending
    /// state, so a state machine at the state will not accept any events.
    ///
    /// A state with a transition leading back to the same state
    /// is not an ending state.
    /// - Parameter state: State to check if it's an ending state.
    /// - Returns: If the state is an ending state.
    public nonisolated func isEndingState(_ state: State) -> Bool {
        return definition.isEndingState(state)
    }
}

// MARK: - Checks of the definition

extension StateMachine {

    // These are about the definition of the state machine as a whole, and
    // are useful for finding mistakes in it. Like the other nonisolated
    // members, they only use constant properties.

    /// All states of the state machine. These are the initial state,
    /// and every state a transition leads from or to.
    public nonisolated var states: Set<State> {
        return definition.graph.states.union([initialState])
    }

    /// All ending states of the state machine. No transitions lead from an
    /// ending state, so a state machine at the state will not accept any events.
    public nonisolated var endingStates: Set<State> {
        return states.filter { isEndingState($0) }
    }

    /// All states that can be reached from a state, by processing no
    /// event, one event or several. The state itself is always one of
    /// them, as it is reached without processing any event.
    ///
    /// A state is reachable from another state exactly when there is
    /// a shortest path between them.
    /// - Parameter state: State to start from.
    /// - Returns: The state, and every state that can be reached from it.
    public nonisolated func reachableStates(from state: State) -> Set<State> {
        return definition.graph.reachableStates(from: state)
    }

    /// All states that cannot be reached from the initial state. The state
    /// machine will never be at any of them.
    ///
    /// An unreachable state is often a mistake in the definition, like a
    /// missing transition, or a transition leading to the wrong state.
    public nonisolated var unreachableStates: Set<State> {
        return states.subtracting(reachableStates(from: initialState))
    }

    /// All states without a path to any ending state. A state machine
    /// getting to one of them will never reach an ending state.
    ///
    /// For a state machine meant to end, such a state is a mistake in the
    /// definition. For a state machine without ending states, meant to go
    /// on forever, these are all its states.
    public nonisolated var statesWithoutPathToEndingState: Set<State> {
        return states.subtracting(definition.graph.states(leadingToAnyOf: endingStates))
    }

    /// If the definition has a cycle. A cycle is a way from a state back to
    /// the same state, by one transition or several. A state machine with
    /// a cycle can go on processing events forever.
    ///
    /// A cycle among unreachable states counts as well, as this
    /// is about the definition and not about the initial state.
    public nonisolated var hasCycle: Bool {
        return definition.graph.hasCycle
    }
}
