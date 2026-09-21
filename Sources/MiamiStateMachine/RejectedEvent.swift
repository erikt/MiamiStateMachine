/// An event rejected by a state machine. There was no transition for
/// the event from the state the state machine was at.
///
/// A rejected event can be encoded when its event and state can, and decoded
/// when they can be decoded. The keys are `event` and `state`.
public struct RejectedEvent<Event: StateMachineEvent, State: Hashable & Sendable> {

    /// The rejected event, with what it carries.
    public let event: Event

    /// The state the state machine was at when rejecting the event.
    public let state: State

    /// Create a rejected event.
    /// - Parameters:
    ///   - event: The rejected event.
    ///   - state: The state the state machine was at when rejecting the event.
    public init(event: Event, state: State) {
        self.event = event
        self.state = state
    }
}

extension RejectedEvent: Sendable { }
extension RejectedEvent: Equatable where Event: Equatable { }
extension RejectedEvent: Hashable where Event: Hashable { }
extension RejectedEvent: Encodable where Event: Encodable, State: Encodable { }
extension RejectedEvent: Decodable where Event: Decodable, State: Decodable { }

extension RejectedEvent: CustomStringConvertible {
    public var description: String {
        return "\(event) rejected at \(state)"
    }
}
