/// A state machine is an actor with a current state and
/// a set of transitions defining the machine. The `Transition`
/// connects two states by an event.
///
/// The state machine is used together with the `StateMachineDelegate`
/// protocol. The `StateMachineDelegate` includes default protocol
/// extension implementations for processing events and many different
/// ways to examine the state machine's states and transitions between
/// those states.
///
/// The state machine actor protects the current state from outside
/// modification. The state only changes by processing events.
public actor StateMachine<Event: Hashable, State: Hashable> {

    /// All defined state machine transitions.
    public private(set) var transitions: Set<Transition<Event,State>>
    
    /// The current state of the state machine
    public private(set) var state: State
    
    /// The transition that led to the current state.
    public var enteredWith: Transition<Event, State>? {
        // Transition on top of the stack is the last commited.
        return transitionLog.peek
    }
    
    /// A stack keeping track of all processed transitions
    /// of the state machine. At some later date, this stack
    /// should be limited at some resonable capacity ... 
    public private(set) var transitionLog: Stack<Transition<Event, State>> = Stack()
    
    /// Creates a new state machine.
    /// This fails if the provided set of transitions does not define
    /// a consistent state machine. There can not be a state where the
    /// same event leads to more than one transition to another state.
    /// - Parameters:
    ///   - initialState: Initial state.
    ///   - transitions: All defined transitions.
    public init?(initialState: State, transitions: Set<Transition<Event,State>>) {
        // Check if transitions define a consistent
        // state machine. All pairs of from state and
        // events, must be unique. Otherwise there is
        // a state where an event leads to different
        // to-states.
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

        self.state = initialState
        self.transitions = transitions
    }
    
    /// Commit transition. Change the current state to the to-state
    /// in the transition and keep track of processed and accepted
    /// transitions in a stack.
    /// - Parameter transition: State machine accepted transition.
    internal func commitTransition(_ transition: Transition<Event, State>) {
        self.state = transition.to
        transitionLog.push(transition)
    }
}

public enum StateMachineDefinitionError: Error {
    case sameStateMultipleEvents
}
