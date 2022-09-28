import Foundation

/// A state machine is an actor with a current state and
/// a set of transitions defining the machine. The `Transition`
/// connects two states by an event.
///
/// The state machine is used together with the `StateMachineDelegate`
/// protocol. The delegate is called when the state has changed
/// or when a processed event did not lead to a state change.
///
/// The state machine actor protects the current state from outside
/// modification. The state only changes by processing events.
///
/// Information about the definition of the state machine can be
/// accessed by non-isolated methods.
public actor StateMachine<Event: Hashable & Sendable, State: Hashable & Sendable> {

    // MARK: - Private properties
    
    /// Transitions defining the state machine.
    private let transitions: Set<Transition<Event, State>>

    /// State machine delegate.
    private unowned let delegate: StateMachineDelegate?

    // MARK: - Public isolated properties
    
    /// The current state of the state machine.
    public private(set) var state: State

    /// The starting state for the state machine.
    public let initialState: State

    /// A log keeping track of all processed transitions
    /// of the state machine. The log has a max capacity of
    /// transitions it keeps track of. When the max capacity
    /// has been reached, it throws away the oldest log
    /// entry.
    public private(set) var transitionLog: CapacityLog<Transition<Event, State>>

    /// Number of events processed. Includes events that
    /// did not lead to a state change for the state machine.
    public private(set) var processedEventsCount: Int = 0
    
    /// Counter for the number of state changes for this state machine.
    public private(set) var stateChangeCount: Int = 0

    // MARK: - Computed properties
    
    /// The transition that led to the current state.
    public var enteredWith: Transition<Event, State>? {
        // Transition on top of the stack is the last commited.
        return transitionLog.peek
    }
    
    /// Counter for the number of events processed that did
    /// not lead to a state change.
    public var rejectedEventsCount: Int {
        return processedEventsCount - stateChangeCount
    }
    
    /// If the state machine is at its initial state and
    /// never has done any state changes since its creation.
    public var atInitialState: Bool {
        return state == initialState && stateChangeCount == 0
    }
    
    /// If the state machine is in a state where there are no
    /// further possible state changes. There's no event leading
    /// to a change of state from this state.
    public var atEndingState: Bool {
        return atEnd(for: state)
    }
    
    /// All possible events (leading to a state change) from
    /// the current state.
    public var eventsFromCurrent: Set<Event> {
        return events(from: state)
    }
    
    /// All events leading (incoming) to the current state.
    public var eventsToCurrent: Set<Event> {
        return events(to: state)
    }
    
    /// All possible outgoing transitions from the current state.
    public var transitionsFromCurrent: Set<Transition<Event, State>> {
        return transitions(from: state)
    }
    
    /// All possible incoming transition leading to the current state.
    public var transitionsToCurrent: Set<Transition<Event, State>> {
        return transitions(to: state)
    }

    // MARK: - Initialization
    
    /// Creates a new state machine.
    /// The state machine definition can not be created if the machine
    /// is not consistent (no state where the same event leads to more
    /// than one transition to another state).
    ///
    /// If this state machine needs to have a delegate (to be informed
    /// when the state changes or not), this needs to be set when
    /// creating the state machine.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - delegate: State machine delegate.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    public init?(transitions: Set<Transition<Event, State>>,
                 initialState: State,
                 delegate: StateMachineDelegate? = nil,
                 logCapacity: UInt? = nil)
    {
        // Check if transitions define a consistent
        // state machine. All pairs of from-state and
        // events, must be unique. Otherwise there is
        // a state where an event leads to multiple
        // different to-states.
        let fromStateAndEventPairs = transitions.map {
            (from: $0.from, event: $0.event)
        }
        
        for pair in fromStateAndEventPairs {
            // Check if each pair in the sequence is unique.
            // If it isn't there is a state with the same
            // event more than once.
            let t = fromStateAndEventPairs.filter { $0 == pair }
            if t.count > 1 {
                return nil
            }
        }
        
        self.transitions = transitions
        self.transitionLog = CapacityLog(capacity: logCapacity)
        self.initialState = initialState
        self.state = initialState
        self.delegate = delegate
    }
    
    // MARK: - API methods
    
    /// Process an event.
    ///
    /// If there is a transition from the current state for the event, the
    /// state machine will change state.
    ///
    /// If there is a delegate, processing an event will either call
    /// `didChangeState(with: Transition)` or `didNotChangeState(from: State, for: Event)`.
    ///
    /// By design there is not a delegate call before a possible state change.
    /// This is to prevent the delegate side-effect changing the state itself and
    /// possibly putting the state machine in an undefined state.
    ///
    /// If no callback queue is set, the delegate callback will be run on the
    /// main queue.
    /// - Parameters:
    ///   - event: Event to process.
    ///   - queue: Queue to call the state machine delegate on.
    public func process(_ event: Event, callbackOn queue: DispatchQueue? = .main) {
        
        // Increase the counter for the number of processed events
        // by the state machine. This includes events process that
        // did not lead to a state change.
        processedEventsCount += 1
        
        if let t = transition(from: state, for: event) {
            commit(t)
            if let delegate, let queue {
                queue.async {
                    delegate.didChangeState(with: t)
                }
            }
        } else {
            if let delegate, let queue {
                let currentState = state
                queue.async {
                    delegate.didNotChangeState(from: currentState, for: event)
                }
            }
        }
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
    public func transitionsFromCurrent(to newState: State) -> Set<Transition<Event, State>> {
        return transitions(from: self.state, to: newState)
    }
    
    /// All possible transitions to the current state, from another state.
    /// - Parameter oldState: From state
    /// - Returns: All possible transitions from a state to the current state.
    public func transitionsToCurrent(from oldState: State) -> Set<Transition<Event, State>> {
        return transitions(from: oldState, to: self.state)
    }

    // MARK: - Private methods
    
    /// Commit transition. Change the current state to the to-state
    /// in the transition and keep track of processed and accepted
    /// transitions in a stack.
    /// - Parameter transition: State machine accepted transition.
    private func commit(_ transition: Transition<Event, State>) {
        state = transition.to
        transitionLog.append(transition)
        stateChangeCount += 1
    }
}

// MARK: - Non-isolated

extension StateMachine {
    
    // These are nonisolated, mostly convenience methods and
    // computed properties. All of them are only interacting
    // with constant properties not in need of state isolation
    // to be safe.
    
    /// Total number of transitions in the state machine.
    public nonisolated var numOfTransitions: Int {
        return transitions.count
    }
    
    /// The transition from a state for an event. If the state
    /// has no transition for the event, it returns nil.
    /// - Parameters:
    ///   - state: From state.
    ///   - event: Event.
    /// - Returns: Transition if there is one for the event at state.
    public nonisolated func transition(from state: State, for event: Event) -> Transition<Event, State>? {
        let ts = transitions.filter { t in
            return t.from == state && t.event == event
        }
        
        if ts.count > 1 {
            fatalError("Error! More than one transition defined from \(state), processing event \(event): \(ts)")
        }

        return ts.first
    }
    
    /// All transitions leading to a state for a specific event.
    /// - Parameters:
    ///   - state: To state.
    ///   - event: Event.
    /// - Returns: All transitions leading to state for an event.
    public nonisolated func transitions(to state: State, for event: Event) -> Set<Transition<Event, State>> {
        return transitions.filter {
            $0.to == state && $0.event == event
        }
    }
    
    /// All possible transitions from a state to another state.
    /// - Parameters:
    ///   - state: Starting state.
    ///   - newState: New state to transition to.
    /// - Returns: All possible transitions to the new state.
    public nonisolated func transitions(from state: State, to newState: State) -> Set<Transition<Event, State>> {
        return transitions.filter {
            $0.from == state && $0.to == newState
        }
    }
    
    /// All possible transitions from a state.
    /// - Parameter state: State to start from.
    /// - Returns: All possible transitions from state.
    public nonisolated func transitions(from state: State) -> Set<Transition<Event, State>> {
        return transitions.filter {
            $0.from == state
        }
    }
    
    public nonisolated func transitions(to state: State) -> Set<Transition<Event, State>> {
        return transitions.filter {
            $0.to == state
        }
    }

    /// All defined and available events handled at a state.
    /// - Parameter state: State.
    /// - Returns: All events going out from this state.
    public nonisolated func events(from state: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.from == state
        }.map {
            $0.event
        })
    }
    
    /// All defined and available events leading to a state.
    /// Please note, the same event could be handled at different
    /// states, all leading to the same state.
    /// - Parameter state: State.
    /// - Returns: All events leading to this state.
    public nonisolated func events(to state: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.to == state
        }.map {
            $0.event
        })
    }
    
    /// All events defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    public nonisolated func events(from: State, to: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.from == from && $0.to == to
        }.map {
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
    
    /// If a state is an end state.
    /// - Parameter state: State to check if it's an end state.
    /// - Returns: If state is an end state.
    public nonisolated func atEnd(for state: State) -> Bool {
        return transitions(from: state).isEmpty
    }
}
