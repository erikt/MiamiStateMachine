/// A transition made by a state machine: the state it led from, the event
/// processed and the state it led to.
///
/// It is like the `StateTransition` of the definition it was made by, but
/// has the event itself, with what the event carries, where the transition
/// of the definition has the event symbol. The transition of the definition
/// is `transition`.
///
/// A transition made can be encoded when its event and states can, and decoded
/// when they can be decoded. The keys are `from`, `event` and `to`, like for
/// a `StateTransition`.
public struct TransitionMade<Event: StateMachineEvent, State: Hashable & Sendable> {

    /// The state the transition led from.
    public let from: State

    /// The event processed, with what it carries.
    public let event: Event

    /// The state the transition led to.
    public let to: State

    /// The transition of the definition that was made.
    public var transition: StateTransition<Event.EventSymbol, State> {
        return StateTransition(from: from, event: event.eventSymbol, to: to)
    }

    /// Create a transition made from a state to another state, by an event.
    /// - Parameters:
    ///   - from: The from state.
    ///   - event: The event processed.
    ///   - to: The to state.
    public init(from: State, event: Event, to: State) {
        self.from = from
        self.event = event
        self.to = to
    }
}

extension TransitionMade: Sendable { }
extension TransitionMade: Equatable where Event: Equatable { }
extension TransitionMade: Hashable where Event: Hashable { }
extension TransitionMade: Encodable where Event: Encodable, State: Encodable { }
extension TransitionMade: Decodable where Event: Decodable, State: Decodable { }

extension TransitionMade: CustomStringConvertible {
    public var description: String {
        return "\(from) --(\(event))--> \(to)"
    }
}
