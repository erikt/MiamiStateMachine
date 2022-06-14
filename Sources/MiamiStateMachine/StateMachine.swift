/// A state machine is an actor with a current state and
/// a set of transitions defining the machine. The `Transition`
/// connects two states by an event.
///
/// The state machine is used together with the `StateMachineDelegate`
/// protocol. The `StateMachineDelegate` includes default implementations
/// for processing events and many different ways to examine the
/// state machine's states and transitions between those states.
///
/// The state machine actor protects the current state from outside
/// modification. The state only changes by processing events.
public actor StateMachine<Event: Hashable, State: Hashable> {
    
    /// The current state of the state machine
    public private(set) var state: State
    
    /// All defined state machine transitions.
    public private(set) var transitions: Set<Transition<Event,State>>
    
    /// Creates a new state machine.
    /// - Parameters:
    ///   - initialState: Initial state.
    ///   - transitions: All defined transitions.
    public init(initialState: State, transitions: Set<Transition<Event,State>>) {
        self.state = initialState
        self.transitions = transitions
    }
    
    /// Changes the current state of the state machine.
    /// - Parameter newState: New state.
    internal func changeState(_ newState: State) {
        self.state = newState
    }
}




