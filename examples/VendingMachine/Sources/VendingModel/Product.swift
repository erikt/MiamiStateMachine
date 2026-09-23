/// A drink for sale, as answered by `GET /products`.
public struct Product: Codable, Equatable, Sendable {

    /// The drink.
    public let drink: Drink

    /// The name of the drink.
    public let name: String

    /// The price of the drink, in cents.
    public let price: Int

    /// How many of the drink are left.
    public let stock: Int

    /// Creates a drink for sale.
    /// - Parameters:
    ///   - drink: The drink.
    ///   - stock: How many of the drink are left.
    public init(_ drink: Drink, stock: Int) {
        self.drink = drink
        self.name = drink.name
        self.price = drink.price
        self.stock = stock
    }
}
