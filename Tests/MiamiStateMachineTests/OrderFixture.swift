import MiamiStateMachine

/// The states of an order in a web shop.
enum OrderState: CaseIterable {
    case cart, checkout, paid, shipped, delivered, cancelled

    /// Not part of any transition.
    case returned
}

/// The events of an order in a web shop.
enum OrderEvent: StateMachineEvent {
    case addItem, checkOut, editCart, pay, buyNow, ship, deliver, cancel

    /// Not part of `OrderFixture.transitions`. Used by tests
    /// adding alternative ways between the states.
    case shipExpress, shipOnInvoice
}

typealias OrderTransition = StateTransition<OrderEvent, OrderState>
typealias OrderStateMachine = StateMachine<OrderEvent, OrderState>

enum OrderFixture {

    /// The definition of a state machine for an order in a web shop.
    ///
    /// The shortest path is unique between all states, but the way with
    /// the fewest events is often not the most obvious one. Buy now is a
    /// short cut past the checkout. The cart and the checkout form a cycle,
    /// and adding an item leads from the cart back to the cart.
    ///
    ///         ┌─ addItem ─┐
    ///         ▼           │
    ///        cart ────────┴─ checkOut ──▶ checkout
    ///         │ ◀──────────── editCart ───── │
    ///         │                              │
    ///       buyNow                          pay
    ///         │                              │
    ///         ▼                              │
    ///        paid ◀──────────────────────────┘
    ///         │
    ///        ship
    ///         ▼
    ///       shipped ── deliver ──▶ delivered
    ///
    /// The order can be cancelled from the cart, the checkout
    /// and when paid. There is no way back from cancelled.
    static let transitions: Set<OrderTransition> = [
        StateTransition(from: .cart, event: .addItem, to: .cart),
        StateTransition(from: .cart, event: .checkOut, to: .checkout),
        StateTransition(from: .cart, event: .buyNow, to: .paid),
        StateTransition(from: .cart, event: .cancel, to: .cancelled),
        StateTransition(from: .checkout, event: .editCart, to: .cart),
        StateTransition(from: .checkout, event: .pay, to: .paid),
        StateTransition(from: .checkout, event: .cancel, to: .cancelled),
        StateTransition(from: .paid, event: .ship, to: .shipped),
        StateTransition(from: .paid, event: .cancel, to: .cancelled),
        StateTransition(from: .shipped, event: .deliver, to: .delivered),
    ]
}
