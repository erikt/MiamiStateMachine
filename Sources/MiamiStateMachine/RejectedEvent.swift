/// An event rejected by a state machine. There was no transition for
/// the event from the state the state machine was at.
public struct RejectedEvent<Event: Hashable & Sendable, State: Hashable & Sendable> {

    /// The rejected event.
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
extension RejectedEvent: Equatable { }
extension RejectedEvent: Hashable { }

extension RejectedEvent: CustomStringConvertible {
    public var description: String {
        return "\(event) rejected at \(state)"
    }
}
