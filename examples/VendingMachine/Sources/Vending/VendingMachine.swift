import MiamiDiagrams
import MiamiStateMachine
import VendingModel

/// A vending machine selling three drinks, with coin input, a coin return,
/// a cancel button and a pickup holding one drink.
///
/// The state machine decides which events are accepted: a drink can only
/// be bought with credit and an empty pickup, the credit can only be
/// cancelled when there is some, and a broken machine only accepts being
/// repaired and refilled. It never looks at what an event carries, so the
/// vending machine keeps the amounts itself, and checks them before an
/// event is processed: that a coin is one the machine takes, that a drink
/// is not sold out, and that the credit covers its price.
///
/// Requests are served one at a time. The state machine is an actor of
/// its own, so a request waits for it, and another request could otherwise
/// change the credit between the check of a request and its transition.
public actor VendingMachine {

    // MARK: - Constants

    /// How many of each drink the machine holds.
    public static let capacity = 5

    /// The coins the machine takes, in cents.
    public static let acceptedCoins: Set<Int> = [5, 10, 25, 100]

    /// The rules defining the state machine of the vending machine.
    public static let rules: Set<TransitionRule<VendingEvent.EventTrigger, VendingState>> = {
        let rules: Set<TransitionRule<VendingEvent.EventTrigger, VendingState>> = [
            TransitionRule(from: .idle, event: .insertCoin, to: .hasCredit),
            TransitionRule(from: .hasCredit, event: .insertCoin, to: .hasCredit),
            TransitionRule(from: .drinkReady, event: .insertCoin, to: .drinkReadyWithCredit),
            TransitionRule(from: .drinkReadyWithCredit, event: .insertCoin, to: .drinkReadyWithCredit),

            // A drink can only be bought when the pickup is empty.
            TransitionRule(from: .hasCredit, event: .select, to: .drinkReady),

            TransitionRule(from: .drinkReady, event: .takeDrink, to: .idle),
            TransitionRule(from: .drinkReadyWithCredit, event: .takeDrink, to: .hasCredit),

            TransitionRule(from: .hasCredit, event: .cancel, to: .idle),
            TransitionRule(from: .drinkReadyWithCredit, event: .cancel, to: .drinkReady),

            TransitionRule(from: .outOfOrder, event: .repair, to: .idle),
        ]

        // The machine can break down at every state, and be refilled at every state.
        return rules
            .union(TransitionRule.from(allExcept: [.outOfOrder], event: .breakDown, to: .outOfOrder))
            .union(TransitionRule.atEveryState(event: .refill))
    }()

    // MARK: - Private properties

    /// The state machine deciding which events are accepted.
    private let stateMachine: StateMachine<VendingEvent, VendingState>

    /// The coins inserted and not yet spent, in cents.
    private var credit = 0

    /// The coins in the coin return, in cents.
    private var coinReturn = 0

    /// The drink in the pickup, if there is one.
    private var pickup: Drink?

    /// How many of each drink are left.
    private var stock = VendingMachine.fullStock

    /// If a request is being served.
    private var isServing = false

    /// The requests waiting for their turn, the first in line first.
    private var waitingInLine: [CheckedContinuation<Void, Never>] = []

    /// Every drink, as many as the machine holds.
    private static var fullStock: [Drink: Int] {
        Dictionary(uniqueKeysWithValues: Drink.allCases.map { ($0, capacity) })
    }

    // MARK: - Initialization

    /// Creates a vending machine, idle and full of drinks.
    public init() {
        do {
            stateMachine = try StateMachine(transitions: Self.rules, initialState: .idle)
        } catch {
            fatalError("The rules of the vending machine are in conflict: \(error.conflictingTransitions)")
        }
    }

    // MARK: - API methods

    /// Processes an event, if the state machine accepts it and the amounts
    /// allow it.
    ///
    /// A coin the machine takes, inserted when coins are not accepted,
    /// falls to the coin return. A coin the machine does not take is handed
    /// straight back, and never gets to the coin return.
    /// - Parameter event: Event to process.
    /// - Returns: The transition made.
    /// - Throws: A `VendingError` telling why the event was not processed.
    public func process(_ event: VendingEvent) async throws(VendingError) -> TransitionEvent<VendingEvent, VendingState> {
        await waitForTurn()
        defer { endTurn() }

        if case .insertCoin(let cents) = event, Self.acceptedCoins.contains(cents) == false {
            throw .coinNotAccepted(cents: cents)
        }

        // No other request is served until this one is done, so the event is
        // accepted at the state the checks were made at.
        let state = await stateMachine.state
        guard stateMachine.transition(from: state, for: event.eventTrigger) != nil else {
            if case .insertCoin(let cents) = event {
                coinReturn += cents
            }
            throw .notAccepted(event: event.eventTrigger, at: state)
        }

        if case .select(let drink) = event {
            guard stock[drink, default: 0] > 0 else {
                throw .soldOut(drink: drink)
            }
            guard credit >= drink.price else {
                throw .notEnoughCredit(for: drink, credit: credit)
            }
        }

        guard let transition = await stateMachine.process(event) else {
            throw .notAccepted(event: event.eventTrigger, at: state)
        }

        switch event {
        case .insertCoin(let cents):
            credit += cents
        case .select(let drink):
            stock[drink, default: 0] -= 1
            pickup = drink
            coinReturn += credit - drink.price
            credit = 0
        case .takeDrink:
            pickup = nil
        case .cancel:
            coinReturn += credit
            credit = 0
        case .breakDown:
            // The credit of a broken machine is lost.
            credit = 0
        case .repair:
            // The technician clears the pickup.
            pickup = nil
        case .refill:
            stock = Self.fullStock
        }
        return transition
    }

    /// Takes the coins in the coin return.
    /// - Returns: The coins taken, in cents.
    public func takeCoins() async -> Int {
        await waitForTurn()
        defer { endTurn() }

        let coins = coinReturn
        coinReturn = 0
        return coins
    }

    /// What the vending machine looks like now.
    /// - Returns: The state, the amounts and the events accepted.
    public func status() async -> VendingStatus {
        await waitForTurn()
        defer { endTurn() }

        let state = await stateMachine.state
        let acceptedEvents = stateMachine.events(from: state)
        return VendingStatus(state: state,
                             credit: credit,
                             coinReturn: coinReturn,
                             pickup: pickup,
                             stock: stock,
                             acceptedEvents: VendingEvent.EventTrigger.allCases.filter(acceptedEvents.contains))
    }

    /// The state machine as a Mermaid diagram, with the current state marked.
    /// - Returns: The text of the diagram.
    public func mermaidDiagram() async -> String {
        await stateMachine.mermaidDiagramWithCurrentState
    }

    /// The state machine as a Graphviz diagram, with the current state marked.
    /// - Returns: The text of the diagram.
    public func dotDiagram() async -> String {
        await stateMachine.dotDiagramWithCurrentState
    }

    // MARK: - Taking turns

    /// Waits until no other request is being served.
    private func waitForTurn() async {
        if isServing {
            await withCheckedContinuation { continuation in
                waitingInLine.append(continuation)
            }
        } else {
            isServing = true
        }
    }

    /// Lets the next request in line be served. The machine stays serving
    /// when there is one, so no request coming in between gets ahead of it.
    private func endTurn() {
        if waitingInLine.isEmpty {
            isServing = false
        } else {
            waitingInLine.removeFirst().resume()
        }
    }
}
