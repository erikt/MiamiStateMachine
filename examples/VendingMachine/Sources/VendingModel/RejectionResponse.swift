/// An event not processed, as answered by `POST /events` with the status 409.
public struct RejectionResponse: Codable, Equatable, Sendable {

    /// Why the event was not processed.
    public let error: VendingError

    /// Why the event was not processed, in words.
    public let reason: String

    /// What the vending machine looks like, unchanged by the event.
    public let machine: VendingStatus

    /// Creates the answer for an event not processed.
    /// - Parameters:
    ///   - error: Why the event was not processed.
    ///   - machine: What the vending machine looks like.
    public init(error: VendingError, machine: VendingStatus) {
        self.error = error
        self.reason = error.description
        self.machine = machine
    }
}
