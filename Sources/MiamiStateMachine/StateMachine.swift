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
    
    /// The transition that lead to the current state.
    public var enteredWith: Transition<Event, State>? {
        return commitStack.peek
    }
    
    /// A stack keeping track of all processed transitions
    /// of the state machine. At some later date, this stack
    /// should be limited at some resonable capacity ... 
    public private(set) var commitStack: Stack<Transition<Event, State>> = Stack()
    
    /// Creates a new state machine.
    /// - Parameters:
    ///   - initialState: Initial state.
    ///   - transitions: All defined transitions.
    public init(initialState: State, transitions: Set<Transition<Event,State>>) {
        self.state = initialState
        self.transitions = transitions
    }
    
    /// Commit transition. Change the current state to the to-state
    /// in the transition and keep track of processed and accepted
    /// transitions in a stack.
    /// - Parameter transition: State machine accepted transition.
    internal func commitTransition(_ transition: Transition<Event, State>) {
        self.state = transition.to
        commitStack.push(transition)
    }
}



