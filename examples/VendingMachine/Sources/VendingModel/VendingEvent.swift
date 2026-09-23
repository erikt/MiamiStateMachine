import MiamiMacros
import MiamiStateMachine

/// Something done to the vending machine, by a customer or a technician.
///
/// The macro writes the triggers the definition is written in, one for
/// every case, without what the case carries.
@StateMachineEvent
public enum VendingEvent: Codable, Equatable, Sendable {

    /// A coin is inserted.
    case insertCoin(cents: Int)

    /// The button of a drink is pushed.
    case select(drink: Drink)

    /// The drink is taken from the pickup.
    case takeDrink

    /// The cancel button is pushed, and the credit is returned.
    case cancel

    /// The machine breaks down.
    case breakDown

    /// A technician repairs the machine, and clears the pickup.
    case repair

    /// The machine is refilled with every drink.
    case refill
}

// A trigger is written as its name, like `"insertCoin"`, instead of the
// object `{"insertCoin":{}}` written for a case without a raw value.
extension VendingEvent.EventTrigger {

    /// The name of the trigger, the same as the name of its event.
    public var name: String {
        String(describing: self)
    }

    public init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let trigger = Self.allCases.first(where: { $0.name == name }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "There is no event named \(name)."))
        }
        self = trigger
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
