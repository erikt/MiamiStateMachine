/// A rule of the definition of a state machine: the transition from a state,
/// for an event, to another state. A rule only leads in one direction.
///
/// A rule can be encoded when its event and states can, and decoded
/// when they can be decoded. The keys are `from`, `event` and `to`.
public struct TransitionRule<Event: Hashable & Sendable, State: Hashable & Sendable> {
    
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

extension TransitionRule: Sendable { }
extension TransitionRule: Equatable { }
extension TransitionRule: Hashable { }
extension TransitionRule: Encodable where Event: Encodable, State: Encodable { }
extension TransitionRule: Decodable where Event: Decodable, State: Decodable { }

extension TransitionRule: CustomStringConvertible {
    public var description: String {
        return "\(from) --(\(event))--> \(to)"
    }
}

