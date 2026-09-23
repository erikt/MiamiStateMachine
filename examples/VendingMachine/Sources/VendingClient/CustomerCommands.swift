import ArgumentParser
import Foundation
import VendingModel

// What a customer does at the vending machine.

extension Vend {

    /// Shows the state of the machine, and the amounts in it.
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show the state of the machine, the credit, the pickup and the stock."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            let answer = try await options.connection.get("machine")
            guard answer.status == 200 else {
                throw ClientError.unexpectedAnswer(answer)
            }
            if options.json {
                answer.printBody()
            } else {
                print(Report.machine(try answer.decode(VendingStatus.self)))
            }
        }
    }

    /// Shows the drinks, with prices and stock.
    struct Products: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show the drinks, with their prices and how many are left."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            let answer = try await options.connection.get("products")
            guard answer.status == 200 else {
                throw ClientError.unexpectedAnswer(answer)
            }
            if options.json {
                answer.printBody()
            } else {
                print(Report.products(try answer.decode([Product].self)))
            }
        }
    }

    /// Inserts coins, one at a time.
    struct Insert: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Insert coins, one at a time. Stops at the first coin not accepted."
        )

        @Argument(help: "Coins, in cents: 5, 10, 25 or 100.")
        var coins: [Int]

        @OptionGroup var options: ConnectionOptions

        func validate() throws {
            guard coins.isEmpty == false else {
                throw ValidationError("Insert at least one coin.")
            }
        }

        func run() async throws {
            for cents in coins {
                try await options.process(.insertCoin(cents: cents))
            }
        }
    }

    /// Pushes the button of a drink.
    struct Select: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Push the button of a drink. The change goes to the coin return."
        )

        @Argument(help: "The drink to buy.")
        var drink: Drink

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            try await options.process(.select(drink: drink))
        }
    }

    /// Takes the drink from the pickup.
    struct TakeDrink: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Take the drink from the pickup."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            try await options.process(.takeDrink)
        }
    }

    /// Pushes the cancel button.
    struct Cancel: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Push the cancel button. The credit goes to the coin return."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            try await options.process(.cancel)
        }
    }

    /// Takes the coins in the coin return.
    struct TakeCoins: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Take the coins in the coin return."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            let answer = try await options.connection.post("coin-return/take")
            guard answer.status == 200 else {
                throw ClientError.unexpectedAnswer(answer)
            }
            if options.json {
                answer.printBody()
            } else {
                print("Took \(dollars(try answer.decode(CoinsResponse.self).cents)).")
            }
        }
    }

    /// Prints the state machine as a diagram.
    struct Diagram: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the state machine as a diagram, with the current state marked."
        )

        /// The formats of a diagram.
        enum Format: String, CaseIterable, ExpressibleByArgument {
            case mermaid
            case dot
        }

        @Option(help: "The format of the diagram.")
        var format = Format.mermaid

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            let answer = try await options.connection.get("diagram", query: [URLQueryItem(name: "format", value: format.rawValue)])
            guard answer.status == 200 else {
                throw ClientError.unexpectedAnswer(answer)
            }
            answer.printBody()
        }
    }
}
