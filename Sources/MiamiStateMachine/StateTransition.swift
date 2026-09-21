/// A transition connects two states via an event. The transition
/// is only defined in one direction (from a state to another state).
///
/// A transition can be encoded when its event and states can, and decoded
/// when they can be decoded. The keys are `from`, `event` and `to`.
public struct StateTransition<Event: Hashable & Sendable, State: Hashable & Sendable> {
    
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

extension StateTransition: Sendable { }
extension StateTransition: Equatable { }
extension StateTransition: Hashable { }
extension StateTransition: Encodable where Event: Encodable, State: Encodable { }
extension StateTransition: Decodable where Event: Decodable, State: Decodable { }

extension StateTransition: CustomStringConvertible {
    public var description: String {
        return "\(from) --(\(event))--> \(to)"
    }
}

