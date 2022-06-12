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
    var transitions: [Transition<Event, State>] { get }
    
    /// The state machine has reached an end state when there
    /// are no events leading to a transition to another state.
    var hasReachedEnd: Bool { get }
    
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
    
    /// All defined and available events handled at a state.
    /// - Parameter state: State.
    /// - Returns: All defined events.
    func events(for state: State) -> [Event]
    
    /// All events defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    func events(from: State, to: State) -> [Event]
    
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
    
    var hasReachedEnd: Bool {
        return events(for: state).isEmpty
    }
    
    mutating func process(_ event: Event) {
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
    
    func events(for state: State) -> [Event] {
        return transitions.filter {
            $0.from == state
        }.map {
            $0.event
        }
    }
    
    func events(from: State, to: State) -> [Event] {
        return transitions.filter {
            $0.from == from && $0.to == to
        }.map {
            $0.event
        }
    }
    
    func transition(from state: State, for event: Event) -> Transition<Event, State>? {
        let ts = transitions.filter { t in
            return t.from == state && t.event == event
        }
        
        if ts.count > 1 {
            fatalError("Error! More than one transition defined from \(state), processing event \(event): \(ts)")
        }

        return ts.first
    }
    
    func willChangeState(with transition: Transition<Event, State>) { }
    func willNotChangeState(for event: Event) { }
    func didChangeState(with transition: Transition<Event, State>) { }
    func didNotChangeState(for event: Event) { }
}



