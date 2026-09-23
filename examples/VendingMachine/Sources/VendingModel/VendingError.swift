/// Why the vending machine did not do what it was asked.
public enum VendingError: Error, Codable, Equatable, Sendable {

    /// The state machine has no transition for the event at the state.
    case notAccepted(event: VendingEvent.EventTrigger, at: VendingState)

    /// The coin is not one the machine takes. It is handed straight back.
    case coinNotAccepted(cents: Int)

    /// The credit is less than the price of the drink.
    case notEnoughCredit(for: Drink, credit: Int)

    /// There is none of the drink left.
    case soldOut(drink: Drink)
}

extension VendingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notAccepted(let event, let state):
            "The event \(event) is not accepted when the machine is at \(state)."
        case .coinNotAccepted(let cents):
            "A \(cents)-cent coin is not accepted."
        case .notEnoughCredit(let drink, let credit):
            "\(drink.name) costs \(dollars(drink.price)), and the credit is \(dollars(credit))."
        case .soldOut(let drink):
            "\(drink.name) is sold out."
        }
    }
}
