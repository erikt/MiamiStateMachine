/// A transition connects two states via an event. The transition
/// is only defined in one direction (from a state to another state).
public struct Transition<Event: Hashable & Sendable, State: Hashable & Sendable> {
    
    /// The transition from state.
    public let from: State
    
    /// The event connecting the from state with the to state.
    public let event: Event
    
    /// The transition to state.
    public let to: State
    
    /// Create a transition from a state to another state,
    /// connected by an event.
    /// - Parameters:
    ///   - from: The from state.
    ///   - event: The event connecting the states.
    ///   - to: The to state.
    public init(from: State, event: Event, to: State) {
        self.from = from
        self.event = event
        self.to = to
    }
}

extension Transition: Sendable { }
extension Transition: Equatable { }
extension Transition: Hashable { }

extension Transition: CustomStringConvertible {
    public var description: String {
        return "\(from) --(\(event))--> \(to)"
    }
}

