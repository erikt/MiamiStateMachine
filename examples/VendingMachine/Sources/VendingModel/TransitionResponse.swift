import MiamiStateMachine

/// An event processed, as answered by `POST /events` with the status 200.
public struct TransitionResponse: Codable, Equatable, Sendable {

    /// The transition the event made.
    public let transition: TransitionEvent<VendingEvent, VendingState>

    /// What the vending machine looks like after the event.
    public let machine: VendingStatus

    /// Creates the answer for an event processed.
    /// - Parameters:
    ///   - transition: The transition the event made.
    ///   - machine: What the vending machine looks like after the event.
    public init(transition: TransitionEvent<VendingEvent, VendingState>, machine: VendingStatus) {
        self.transition = transition
        self.machine = machine
    }
}
