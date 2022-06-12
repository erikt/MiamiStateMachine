/// A state machine has states and transitions between the
/// different states. A transition to another state happens
/// when the state machine processes an event.
///
/// A conforming type needs to define the possible states (with
/// an enum for example, but anything hashable works as well) and
/// the transitions between the states.
///
/// Any possible side effects when doing a transition between
/// states, can be handled before and after the actual state
/// change. The same goes for when an event does not trigger
/// a state change.
public protocol StateMachine {
    associatedtype State: Hashable
    associatedtype Event: Hashable
    
    /// Current state of the state machine.
    ///
    /// Preferably this would only be accessed from the state
    /// machine protocol extension, when processing events, but
    /// this is not possible at the moment. Protect the state
    /// from modification in the conforming type.
    var state: State { get set }
    
    /// All transitions in the state machine.
    var transitions: Set<Transition<Event, State>> { get }
    
    /// The state machine has reached an end state when there
    /// are no events leading to a transition to another state.
    var atEndingState: Bool { get }
    
    /// All possible events at the current state.
    var eventsAtCurrentState: Set<Event> { get }
    
    /// All possible transitions from the current state.
    var transitionsAtCurrentState: Set<Transition<Event, State>> { get }
    
    /// Process an event. The state machine will change state
    /// if there is a transition from the current state with
    /// this event.
    ///
    /// Please note, if the conforming state machine implementation
    /// is a value type, processing events may mutate the value if
    /// the event leads to a transition to a new state.
    /// - Parameter event: Event to process.
    mutating func process(_ event: Event)
    
    /// The transition from a state for an event. If the state
    /// has no transition for the event, it returns nil.
    /// - Parameters:
    ///   - state: From state.
    ///   - event: Event.
    /// - Returns: Transition if there is one for the event at state.
    func transition(from state: State, for event: Event) -> Transition<Event, State>?
    
    /// All possible transitions from a state to another state.
    /// - Parameters:
    ///   - state: Starting state.
    ///   - newState: New state to transition to.
    /// - Returns: All possible transitions to the new state.
    func transitions(from state: State, to newState: State) -> Set<Transition<Event, State>>
    
    /// All possible transitions from a state.
    /// - Parameter state: State to start from.
    /// - Returns: All possible transitions from state.
    func transitions(from state: State) -> Set<Transition<Event, State>>
    
    /// All possible transitions from the current state to a new state.
    /// - Parameter newState: New state.
    /// - Returns: All transitions from the current state to a new state.
    func transitions(to newState: State) -> Set<Transition<Event, State>>
    
    /// Is it possible to transition from the current state to the new state.
    /// - Parameter newState: The new state.
    /// - Returns: If it is possible to go from the current state to a new state.
    func canTransition(to newState: State) -> Bool
    
    /// All defined and available events handled at a state.
    /// - Parameter state: State.
    /// - Returns: All defined events.
    func events(for state: State) -> Set<Event>
    
    /// All events defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    func events(from: State, to: State) -> Set<Event>
    
    /// The state machine is processing an event and will soon
    /// transition and change to another state.
    /// - Parameter transition: Transition involved in state change.
    func willChangeState(with transition: Transition<Event, State>)
    
    /// The state machine has processed an event and transitioned
    /// and changed to another state.
    /// - Parameter transition: Transition that changed state.
    func didChangeState(with transition: Transition<Event, State>)
    
    /// The state machine is processing an event, but there are no
    /// defined transitions from the current state for this event.
    /// There will be no change of state.
    /// - Parameter event: Event that will not change state.
    func willNotChangeState(for event: Event)
    
    /// The state machine has process and event, but there was no
    /// defined transition from the current state for this event.
    /// There was no change of state.
    /// - Parameter event: Event that did not change state.
    func didNotChangeState(for event: Event)
}

extension StateMachine {
    
    public var atEndingState: Bool {
        return events(for: state).isEmpty
    }
    
    public var eventsAtCurrentState: Set<Event> {
        return events(for: state)
    }
    
    public var transitionsAtCurrentState: Set<Transition<Event, State>> {
        return transitions(from: state)
    }
    
    public mutating func process(_ event: Event) {
        if let t = transition(from: state, for: event) {
            willChangeState(with: t)
            state = t.to
            didChangeState(with: t)
        } else {
            // TODO: This seems silly ...
            willNotChangeState(for: event)
            didNotChangeState(for: event)
        }
    }
    
    public func events(for state: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.from == state
        }.map {
            $0.event
        })
    }
    
    public func events(from: State, to: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.from == from && $0.to == to
        }.map {
            $0.event
        })
    }
    
    public func transition(from state: State, for event: Event) -> Transition<Event, State>? {
        let ts = transitions.filter { t in
            return t.from == state && t.event == event
        }
        
        if ts.count > 1 {
            fatalError("Error! More than one transition defined from \(state), processing event \(event): \(ts)")
        }

        return ts.first
    }
    
    public func transitions(from state: State, to newState: State) -> Set<Transition<Event, State>> {
        return transitions.filter {
            $0.from == state && $0.to == newState
        }
    }
    
    public func transitions(from state: State) -> Set<Transition<Event, State>> {
        return transitions.filter {
            $0.from == state
        }
    }
    
    public func transitions(to newState: State) -> Set<Transition<Event, State>> {
        return transitions(from: state, to: newState)
    }
    
    public func canTransition(to newState: State) -> Bool {
        return !transitions(from: state, to: newState).isEmpty
    }
    
    public func willChangeState(with transition: Transition<Event, State>) { }
    public func willNotChangeState(for event: Event) { }
    public func didChangeState(with transition: Transition<Event, State>) { }
    public func didNotChangeState(for event: Event) { }
}



