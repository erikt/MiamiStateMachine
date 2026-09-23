import ArgumentParser
import Foundation
import VendingModel

/// A command line client for the vending machine server.
@main
struct Vend: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vend",
        abstract: "Buys drinks from a vending machine server.",
        subcommands: [
            Status.self,
            Products.self,
            Insert.self,
            Select.self,
            TakeDrink.self,
            Cancel.self,
            TakeCoins.self,
            Diagram.self,
        ],
        groupedSubcommands: [
            CommandGroup(name: "Technician", subcommands: [
                BreakDown.self,
                Repair.self,
                Refill.self,
            ]),
        ]
    )
}

/// The options every command takes: where the server is, and how to print
/// what it answers.
struct ConnectionOptions: ParsableArguments {

    @Option(help: "The URL of the vending machine server.")
    var server = "http://127.0.0.1:8080"

    @Flag(help: "Print the JSON the server answers with, instead of text.")
    var json = false

    /// The server to send requests to.
    var connection: Server {
        get throws {
            guard let url = URL(string: server), url.scheme == "http" || url.scheme == "https" else {
                throw ValidationError("The server is not a URL like http://127.0.0.1:8080.")
            }
            return Server(url: url)
        }
    }

    /// Sends an event to the vending machine, and prints what it led to.
    ///
    /// An event not processed is printed to standard error, and the
    /// command ends with the exit code 1.
    /// - Parameter event: Event to send.
    func process(_ event: VendingEvent) async throws {
        let answer = try await connection.post("events", json: event)
        switch answer.status {
        case 200:
            if json {
                answer.printBody()
            } else {
                print(Report.transition(try answer.decode(TransitionResponse.self)))
            }
        case 409:
            if json {
                answer.printBody()
            } else {
                let rejection = try answer.decode(RejectionResponse.self)
                printError(rejection.reason)
                print(Report.summary(rejection.machine))
            }
            throw ExitCode.failure
        default:
            throw ClientError.unexpectedAnswer(answer)
        }
    }
}

/// Prints a line to standard error.
/// - Parameter text: The text to print.
func printError(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}
