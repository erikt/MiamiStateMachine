/// The coins taken from the coin return, as answered by `POST /coin-return/take`.
public struct CoinsResponse: Codable, Equatable, Sendable {

    /// The coins taken, in cents.
    public let cents: Int

    /// Creates the answer for coins taken.
    /// - Parameter cents: The coins taken, in cents.
    public init(cents: Int) {
        self.cents = cents
    }
}
