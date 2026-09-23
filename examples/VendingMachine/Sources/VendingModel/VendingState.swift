/// Where the vending machine is in a sale. How much credit there is and how
/// many drinks are left are not states, but kept by the `VendingMachine`.
public enum VendingState: String, CaseIterable, Codable, Sendable {

    /// No credit, and nothing in the pickup.
    case idle

    /// Coins have been inserted, and the pickup is empty.
    case hasCredit

    /// A drink is in the pickup, and there is no credit.
    case drinkReady

    /// A drink is in the pickup, and the next customer has inserted coins.
    case drinkReadyWithCredit

    /// The machine has broken down, and has to be repaired.
    case outOfOrder
}
