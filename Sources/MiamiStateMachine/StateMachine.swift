/// A state machine has states and transitions between the
/// different states. A transition to another state happens
/// when the state machine processes an event.
///
/// A conforming type needs to define the possible states (with
/// an enum for example, but anything hashable works as well) and
/// the transitions between the states.
///
/// Any possible side effects when doing a transition between
/// states, can be after the actual state change. The same goes
/// for when an event does not trigger a state change.
public protocol StateMachine {
    associatedtype State: Hashable
    associatedtype Event: Hashable
    
    /// Current state of the state machine.
    var state: State { get async }
    
    /// Guard for the current state of the state machine.
    /// It is an actor that makes sure the state property is safe
    /// for manipulation concurrently.
    var smGuard: StateMachineGuard<Event, State> { get }
    
    /// All transitions in the state machine.
    var transitions: Set<Transition<Event, State>> { get async }
    
    /// The state machine has reached an end state when there
    /// are no events leading to a transition to another state.
    var atEndingState: Bool { get async }
    
    /// All possible events at the current state.
    var eventsAtCurrentState: Set<Event> { get async }
    
    /// All possible transitions from the current state.
    var transitionsAtCurrentState: Set<Transition<Event, State>> { get async }
    
    /// Process an event. The state machine will change state
    /// if there is a transition from the current state with
    /// this event.
    /// - Parameter event: Event to process.
    func process(_ event: Event) async
    
    /// The transition from a state for an event. If the state
    /// has no transition for the event, it returns nil.
    /// - Parameters:
    ///   - state: From state.
    ///   - event: Event.
    /// - Returns: Transition if there is one for the event at state.
    func transition(from state: State, for event: Event) async -> Transition<Event, State>?
    
    /// All possible transitions from a state to another state.
    /// - Parameters:
    ///   - state: Starting state.
    ///   - newState: New state to transition to.
    /// - Returns: All possible transitions to the new state.
    func transitions(from state: State, to newState: State) async -> Set<Transition<Event, State>>
    
    /// All possible transitions from a state.
    /// - Parameter state: State to start from.
    /// - Returns: All possible transitions from state.
    func transitions(from state: State) async -> Set<Transition<Event, State>>
    
    /// All possible transitions from the current state to a new state.
    /// - Parameter newState: New state.
    /// - Returns: All transitions from the current state to a new state.
    func transitions(to newState: State) async -> Set<Transition<Event, State>>
    
    /// Is it possible to transition from the current state to the new state.
    /// - Parameter newState: The new state.
    /// - Returns: If it is possible to go from the current state to a new state.
    func canTransition(to newState: State) async -> Bool
    
    /// All defined and available events handled at a state.
    /// - Parameter state: State.
    /// - Returns: All defined events.
    func events(for state: State) async -> Set<Event>
    
    /// All events defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    func events(from: State, to: State) async -> Set<Event>
    
    /// The state machine has processed an event and transitioned
    /// and changed to another state.
    /// - Parameter transition: Transition that changed state.
    func didChangeState(with transition: Transition<Event, State>)
    
    /// The state machine has process and event, but there was no
    /// defined transition from the current state for this event.
    /// There was no change of state.
    /// - Parameter event: Event that did not change state.
    func didNotChangeState(from state: State, for event: Event)
}

extension StateMachine {
    
    public var state: State {
        get async {
            return await smGuard.state
        }
    }
    
    public var transitions: Set<Transition<Event, State>> {
        get async {
            return await smGuard.transitions
        }
    }
    
    public var atEndingState: Bool {
        get async {
            return await events(for: smGuard.state).isEmpty
        }
    }
    
    public var eventsAtCurrentState: Set<Event> {
        get async {
            return await events(for: smGuard.state)
        }
    }
    
    public var transitionsAtCurrentState: Set<Transition<Event, State>> {
        get async {
            return await transitions(from: smGuard.state)
        }
    }
    
    public func process(_ event: Event) async {
        if let t = await transition(from: smGuard.state, for: event) {
            await smGuard.changeState(t.to)
            await MainActor.run {
                didChangeState(with: t)
            }
        } else {
            let currentState = await smGuard.state
            await MainActor.run {
                didNotChangeState(from: currentState, for: event)
            }
        }
    }
    
    public func events(for state: State) async -> Set<Event> {
        return await Set<Event>(transitions.filter {
            $0.from == state
        }.map {
            $0.event
        })
    }
    
    public func events(from: State, to: State) async -> Set<Event> {
        return await Set<Event>(transitions.filter {
            $0.from == from && $0.to == to
        }.map {
            $0.event
        })
    }
    
    public func transition(from state: State, for event: Event) async -> Transition<Event, State>? {
        let ts = await transitions.filter { t in
            return t.from == state && t.event == event
        }
        
        if ts.count > 1 {
            fatalError("Error! More than one transition defined from \(state), processing event \(event): \(ts)")
        }

        return ts.first
    }
    
    public func transitions(from state: State, to newState: State) async -> Set<Transition<Event, State>> {
        return await transitions.filter {
            $0.from == state && $0.to == newState
        }
    }
    
    public func transitions(from state: State) async -> Set<Transition<Event, State>> {
        return await transitions.filter {
            $0.from == state
        }
    }
    
    public func transitions(to newState: State) async -> Set<Transition<Event, State>> {
        return await transitions(from: smGuard.state, to: newState)
    }
    
    public func canTransition(to newState: State) async -> Bool {
        return await !transitions(from: smGuard.state, to: newState).isEmpty
    }
    
    public func didChangeState(with transition: Transition<Event, State>) { }
    public func didNotChangeState(from state: State, for event: Event) { }
}
