import MiamiDiagrams
import MiamiStateMachine
import VendingModel

/// A vending machine selling three drinks, with coin input, a coin return,
/// a cancel button and a pickup holding one drink.
///
/// The state machine decides which events are accepted: a drink can only
/// be bought with credit and an empty pickup, the credit can only be
/// cancelled when there is some, and a broken machine only accepts being
/// repaired and refilled. The credit, the pickup and the stock are its
/// context, changed by the actions of its transitions, with what the events
/// carry. It never looks at them to choose a transition, so the vending
/// machine checks them before an event is processed: that a coin is one the
/// machine takes, that a drink is not sold out, and that the credit covers
/// its price. The coin return is kept by the vending machine, as coins get
/// there without a transition too.
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

    /// The rules defining the state machine of the vending machine, with the
    /// actions changing its context.
    @TransitionRuleBuilder<VendingEvent, VendingState, VendingContext>
    public static var rules: TransitionRules<VendingEvent, VendingState, VendingContext> {
        From(.idle) {
            On(.insertCoin, to: .hasCredit, action: addCoin)
        }
        From(.hasCredit) {
            On(.insertCoin, to: .hasCredit, action: addCoin)
            // A drink can only be bought when the pickup is empty.
            On(.select, to: .drinkReady, action: sell)
            On(.cancel, to: .idle, action: clearCredit)
        }
        From(.drinkReady) {
            On(.insertCoin, to: .drinkReadyWithCredit, action: addCoin)
            On(.takeDrink, to: .idle, action: emptyPickup)
        }
        From(.drinkReadyWithCredit) {
            On(.insertCoin, to: .drinkReadyWithCredit, action: addCoin)
            On(.takeDrink, to: .hasCredit, action: emptyPickup)
            On(.cancel, to: .drinkReady, action: clearCredit)
        }
        From(.outOfOrder) {
            // The technician clears the pickup.
            On(.repair, to: .idle, action: emptyPickup)
        }

        // The machine can break down at every state, and be refilled at every state.
        From(allExcept: [.outOfOrder]) {
            // The credit of a broken machine is lost.
            On(.breakDown, to: .outOfOrder, action: clearCredit)
        }
        AtEveryState(.refill) { context, _ in
            context.stock = fullStock
        }
    }

    // MARK: - Actions

    /// Adds an inserted coin to the credit.
    private static let addCoin: TransitionAction<VendingEvent, VendingState, VendingContext> = { context, transition in
        if case .insertCoin(let cents) = transition.event {
            context.credit += cents
        }
    }

    /// Puts the drink selected in the pickup, and spends the credit. What is
    /// left of the credit is returned by the vending machine.
    private static let sell: TransitionAction<VendingEvent, VendingState, VendingContext> = { context, transition in
        if case .select(let drink) = transition.event {
            context.stock[drink, default: 0] -= 1
            context.pickup = drink
            context.credit = 0
        }
    }

    /// Clears the credit, returned by the vending machine when cancelled,
    /// and lost when the machine breaks down.
    private static let clearCredit: TransitionAction<VendingEvent, VendingState, VendingContext> = { context, _ in
        context.credit = 0
    }

    /// Empties the pickup.
    private static let emptyPickup: TransitionAction<VendingEvent, VendingState, VendingContext> = { context, _ in
        context.pickup = nil
    }

    // MARK: - Private properties

    /// The state machine deciding which events are accepted, with the credit,
    /// the pickup and the stock as its context.
    private let stateMachine: StateMachine<VendingEvent, VendingState, VendingContext>

    /// The coins in the coin return, in cents.
    private var coinReturn = 0

    /// If a request is being served.
    private var isServing = false

    /// The requests waiting for their turn, the first in line first.
    private var waitingInLine: [CheckedContinuation<Void, Never>] = []

    /// Every drink, as many as the machine holds.
    static var fullStock: [Drink: Int] {
        Dictionary(uniqueKeysWithValues: Drink.allCases.map { ($0, capacity) })
    }

    // MARK: - Initialization

    /// Creates a vending machine, idle and full of drinks.
    public init() {
        do {
            stateMachine = try StateMachine(initialState: .idle, context: VendingContext()) { Self.rules }
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

        let context = await stateMachine.context
        if case .select(let drink) = event {
            guard context.stock[drink, default: 0] > 0 else {
                throw .soldOut(drink: drink)
            }
            guard context.credit >= drink.price else {
                throw .notEnoughCredit(for: drink, credit: context.credit)
            }
        }

        guard let transition = await stateMachine.process(event) else {
            throw .notAccepted(event: event.eventTrigger, at: state)
        }

        // The actions have changed the context. What they spent of the
        // credit and did not keep goes to the coin return.
        switch event {
        case .select(let drink):
            coinReturn += context.credit - drink.price
        case .cancel:
            coinReturn += context.credit
        default:
            break
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
        let context = await stateMachine.context
        let acceptedEvents = stateMachine.events(from: state)
        return VendingStatus(state: state,
                             credit: context.credit,
                             coinReturn: coinReturn,
                             pickup: context.pickup,
                             stock: context.stock,
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

// MARK: - Context

/// What the transitions of the vending machine change besides its state:
/// the credit, the drink in the pickup, and the drinks left.
public struct VendingContext: Sendable, Equatable {

    /// The coins inserted and not yet spent, in cents.
    public var credit = 0

    /// The drink in the pickup, if there is one.
    public var pickup: Drink?

    /// How many of each drink are left.
    public var stock = VendingMachine.fullStock
}
