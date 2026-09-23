/// What the vending machine looks like at one moment, as answered by
/// `GET /machine`, and with every answer to `POST /events`.
public struct VendingStatus: Codable, Equatable, Sendable {

    /// Where the machine is in a sale.
    public let state: VendingState

    /// The coins inserted and not yet spent, in cents.
    public let credit: Int

    /// The coins in the coin return, waiting to be taken, in cents.
    public let coinReturn: Int

    /// The drink in the pickup, if there is one.
    public let pickup: Drink?

    /// How many of each drink are left.
    public let stock: [Drink: Int]

    /// The event triggers the state machine accepts at the state, in the
    /// order the events are declared.
    public let acceptedEvents: [VendingEvent.EventTrigger]

    /// Creates what the vending machine looks like.
    /// - Parameters:
    ///   - state: Where the machine is in a sale.
    ///   - credit: The coins inserted and not yet spent, in cents.
    ///   - coinReturn: The coins in the coin return, in cents.
    ///   - pickup: The drink in the pickup, if there is one.
    ///   - stock: How many of each drink are left.
    ///   - acceptedEvents: The event triggers accepted at the state.
    public init(state: VendingState,
                credit: Int,
                coinReturn: Int,
                pickup: Drink?,
                stock: [Drink: Int],
                acceptedEvents: [VendingEvent.EventTrigger])
    {
        self.state = state
        self.credit = credit
        self.coinReturn = coinReturn
        self.pickup = pickup
        self.stock = stock
        self.acceptedEvents = acceptedEvents
    }
}
