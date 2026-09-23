/// A drink sold by the vending machine. There is a button for each.
public enum Drink: String, CaseIterable, Codable, Sendable {
    case cokeZero
    case pepsiMax
    case trocadero

    /// The name of the drink, as written on its button.
    public var name: String {
        switch self {
        case .cokeZero: "Coke Zero"
        case .pepsiMax: "Pepsi Max"
        case .trocadero: "Trocadero"
        }
    }

    /// The price of the drink, in cents.
    public var price: Int {
        switch self {
        case .cokeZero: 100
        case .pepsiMax: 150
        case .trocadero: 200
        }
    }
}

// A dictionary keyed by drinks is written as a JSON object, and not as an array.
extension Drink: CodingKeyRepresentable { }
