/// Writes an amount in dollars, like `$1.50`.
/// - Parameter cents: The amount, in cents.
/// - Returns: The amount in dollars, with two decimals.
public func dollars(_ cents: Int) -> String {
    let fraction = cents % 100
    return "$\(cents / 100).\(fraction < 10 ? "0" : "")\(fraction)"
}
