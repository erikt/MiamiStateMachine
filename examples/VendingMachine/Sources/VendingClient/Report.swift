import Foundation
import VendingModel

/// The answers of the server, written for people to read.
enum Report {

    /// The command of the client sending each event.
    private static let commands: [VendingEvent.EventTrigger: String] = [
        .insertCoin: "insert",
        .select: "select",
        .takeDrink: "take-drink",
        .cancel: "cancel",
        .breakDown: "break-down",
        .repair: "repair",
        .refill: "refill",
    ]

    /// What the vending machine looks like, one thing on each line.
    /// - Parameter status: The status of the machine.
    /// - Returns: The text.
    static func machine(_ status: VendingStatus) -> String {
        let stock = Drink.allCases
            .map { "\($0.name) \(status.stock[$0, default: 0])" }
            .joined(separator: ", ")
        let commands = status.acceptedEvents
            .map { Self.commands[$0] ?? $0.name }
            .joined(separator: ", ")
        return """
            State        \(status.state)
            Credit       \(dollars(status.credit))
            Coin return  \(dollars(status.coinReturn))
            Pickup       \(status.pickup?.name ?? "empty")
            Stock        \(stock)
            Accepts      \(commands)
            """
    }

    /// The amounts of the vending machine, on one line.
    /// - Parameter status: The status of the machine.
    /// - Returns: The text.
    static func summary(_ status: VendingStatus) -> String {
        "Credit \(dollars(status.credit)), coin return \(dollars(status.coinReturn)), "
            + "pickup \(status.pickup?.name ?? "empty")."
    }

    /// What an event did, and the amounts after it.
    /// - Parameter response: The answer to the event.
    /// - Returns: The text.
    static func transition(_ response: TransitionResponse) -> String {
        let transition = response.transition
        return """
            \(phrase(for: transition.event)): \(transition.from) → \(transition.to)
            \(summary(response.machine))
            """
    }

    /// The drinks for sale, one on each line.
    /// - Parameter products: The drinks.
    /// - Returns: The text.
    static func products(_ products: [Product]) -> String {
        products
            .map { product in
                let stock = product.stock > 0 ? "\(product.stock) left" : "sold out"
                return [product.drink.argument, product.name, dollars(product.price)]
                    .map { $0.padding(toLength: 12, withPad: " ", startingAt: 0) }
                    .joined() + stock
            }
            .joined(separator: "\n")
    }

    /// What an event is, said as done.
    /// - Parameter event: The event.
    /// - Returns: The text.
    static func phrase(for event: VendingEvent) -> String {
        switch event {
        case .insertCoin(let cents): "Inserted \(dollars(cents))"
        case .select(let drink): "Selected \(drink.name)"
        case .takeDrink: "Took the drink"
        case .cancel: "Cancelled"
        case .breakDown: "Broke down"
        case .repair: "Repaired"
        case .refill: "Refilled"
        }
    }
}
