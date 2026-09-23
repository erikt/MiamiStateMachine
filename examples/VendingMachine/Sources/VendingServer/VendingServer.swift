import ArgumentParser
import Hummingbird
import MiamiStateMachine
import Vending
import VendingModel

/// A server for one vending machine, with a JSON API:
///
/// - `GET /machine`: the state, the amounts and the events accepted.
/// - `GET /products`: the drinks, with prices and stock.
/// - `POST /events`: processes an event, like `{"insertCoin":{"cents":100}}`.
///   Answers 200 with the transition, or 409 with why it was not processed.
/// - `POST /coin-return/take`: takes the coins in the coin return.
/// - `GET /diagram?format=mermaid` or `dot`: the state machine as a diagram.
@main
struct VendingServer: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Serves a vending machine, with a JSON API."
    )

    @Option(help: "The address to listen on.")
    var hostname = "127.0.0.1"

    @Option(help: "The port to listen on.")
    var port = 8080

    func run() async throws {
        let machine = VendingMachine()
        let app = Application(
            router: Self.makeRouter(for: machine),
            configuration: .init(address: .hostname(hostname, port: port))
        )
        try await app.runService()
    }

    /// Makes the routes of the API.
    /// - Parameter machine: The vending machine served.
    /// - Returns: The router.
    static func makeRouter(for machine: VendingMachine) -> Router<BasicRequestContext> {
        let router = Router()

        router.get("machine") { _, _ in
            try json(await machine.status())
        }

        router.get("products") { _, _ in
            let stock = await machine.status().stock
            return try json(Drink.allCases.map { Product($0, stock: stock[$0, default: 0]) })
        }

        router.post("events") { request, context in
            let event = try await request.decode(as: VendingEvent.self, context: context)
            let transition: TransitionEvent<VendingEvent, VendingState>
            do throws(VendingError) {
                transition = try await machine.process(event)
            } catch {
                return try json(RejectionResponse(error: error, machine: await machine.status()), status: .conflict)
            }
            return try json(TransitionResponse(transition: transition, machine: await machine.status()))
        }

        router.post("coin-return/take") { _, _ in
            try json(CoinsResponse(cents: await machine.takeCoins()))
        }

        router.get("diagram") { request, _ in
            switch request.uri.queryParameters.get("format") ?? "mermaid" {
            case "mermaid":
                return text(await machine.mermaidDiagram())
            case "dot":
                return text(await machine.dotDiagram())
            default:
                throw HTTPError(.badRequest, message: "The format of a diagram is mermaid or dot.")
            }
        }

        return router
    }
}
