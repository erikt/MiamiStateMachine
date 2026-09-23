import ArgumentParser
import VendingModel

// What happens to the vending machine, and what a technician does.

extension Vend {

    /// Breaks the machine down.
    struct BreakDown: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Break the machine down. The credit is lost."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            try await options.process(.breakDown)
        }
    }

    /// Repairs the machine.
    struct Repair: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Repair the machine, and clear the pickup."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            try await options.process(.repair)
        }
    }

    /// Refills the machine.
    struct Refill: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Refill the machine with five of every drink."
        )

        @OptionGroup var options: ConnectionOptions

        func run() async throws {
            try await options.process(.refill)
        }
    }
}
