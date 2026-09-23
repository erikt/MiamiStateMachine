/// A transition made by a state machine, when it processed an event: the
/// state it led from, the event processed and the state it led to.
///
/// It is like the `TransitionRule` it followed, but has the event itself, with
/// what the event carries, where the rule has the event trigger. The rule is
/// `rule`.
///
/// A transition event can be encoded when its event and states can, and decoded
/// when they can be decoded. The keys are `from`, `event` and `to`, like for
/// a `TransitionRule`.
public struct TransitionEvent<Event: StateMachineEvent, State: Hashable & Sendable> {

    /// The state the transition led from.
    public let from: State

    /// The event processed, with what it carries.
    public let event: Event

    /// The state the transition led to.
    public let to: State

    /// The rule of the definition that the transition followed.
    public var rule: TransitionRule<Event.EventTrigger, State> {
        return TransitionRule(from: from, event: event.eventTrigger, to: to)
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

extension TransitionEvent: Sendable { }
extension TransitionEvent: Equatable where Event: Equatable { }
extension TransitionEvent: Hashable where Event: Hashable { }
extension TransitionEvent: Encodable where Event: Encodable, State: Encodable { }
extension TransitionEvent: Decodable where Event: Decodable, State: Decodable { }

extension TransitionEvent: CustomStringConvertible {
    public var description: String {
        return "\(from) --(\(event))--> \(to)"
    }
}
