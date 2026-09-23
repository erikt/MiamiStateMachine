import ArgumentParser
import VendingModel

// A drink is given on the command line as `coke-zero`, `pepsi-max` or
// `trocadero`. Its case name and its name are read too, in any case.
extension Drink: ExpressibleByArgument {

    /// The drink as written on the command line.
    var argument: String {
        name.lowercased().replacing(" ", with: "-")
    }

    public init?(argument: String) {
        let letters = { (text: String) in text.lowercased().filter(\.isLetter) }
        guard let drink = Self.allCases.first(where: { letters($0.name) == letters(argument) }) else {
            return nil
        }
        self = drink
    }

    public var defaultValueDescription: String {
        argument
    }

    public static var allValueStrings: [String] {
        allCases.map(\.argument)
    }
}
