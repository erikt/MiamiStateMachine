public actor StateMachineGuard<Event: Hashable, State: Hashable> {
    public private(set) var state: State
    public private(set) var transitions: Set<Transition<Event,State>>
    
    public init(initialState: State, transitions: Set<Transition<Event,State>>) {
        self.state = initialState
        self.transitions = transitions
    }
    
    public func changeState(_ newState: State) {
        self.state = newState
    }
}




