/// Builds the rules of a state machine, state by state, with the events
/// leading from each state:
///
///     let stateMachine = try StateMachine<OrderEvent, OrderState>(initialState: .cart) {
///         From(.cart) {
///             On(.checkOut, to: .checkout)
///             On(.cancel, to: .cancelled)
///         }
///         From(.checkout) {
///             On(.pay, to: .paid)
///         }
///     }
///
/// Besides `From`, the rules can be given as `AtEveryState`, as a single
/// `TransitionRule`, or as a set of them. `if`, `switch` and `for` can be used
/// as in any other code.
///
/// The rules are written in event triggers, as a definition always is. The
/// types of the events and the states cannot be inferred from the rules, so
/// they have to be written, like `StateMachine<OrderEvent, OrderState>`.
///
/// The rules are an ordinary set of rules. Conflicting rules are found when
/// the state machine is created, like for any other set.
@resultBuilder
public enum TransitionRuleBuilder<Event: Hashable & Sendable, State: Hashable & Sendable> {

    /// The rules built.
    public typealias Rules = Set<TransitionRule<Event, State>>

    // MARK: - Expressions

    /// The rules for the events leading from one or more states.
    public static func buildExpression(_ from: From<Event, State>) -> Rules {
        return from.rules
    }

    /// A single rule.
    public static func buildExpression(_ rule: TransitionRule<Event, State>) -> Rules {
        return [rule]
    }

    /// A set of rules, like the ones made by `TransitionRule.from(allExcept:event:to:)`.
    public static func buildExpression(_ rules: Rules) -> Rules {
        return rules
    }

    // MARK: - Blocks

    /// All the rules of a block together.
    public static func buildBlock(_ parts: Rules...) -> Rules {
        return parts.reduce(into: []) { $0.formUnion($1) }
    }

    /// The rules of an `if` without an `else`, or none when its condition is false.
    public static func buildOptional(_ rules: Rules?) -> Rules {
        return rules ?? []
    }

    /// The rules of the first branch of an `if` or a `switch`.
    public static func buildEither(first rules: Rules) -> Rules {
        return rules
    }

    /// The rules of the second branch of an `if` or a `switch`.
    public static func buildEither(second rules: Rules) -> Rules {
        return rules
    }

    /// The rules of every round of a `for` loop together.
    public static func buildArray(_ parts: [Rules]) -> Rules {
        return parts.reduce(into: []) { $0.formUnion($1) }
    }

    /// The rules of an `if #available`.
    public static func buildLimitedAvailability(_ rules: Rules) -> Rules {
        return rules
    }
}

extension TransitionRuleBuilder where State: CaseIterable {

    /// The rules for an event at every state, leading back to the same state.
    public static func buildExpression(_ stay: AtEveryState<Event, State>) -> Rules {
        return stay.rules
    }
}

/// Builds the events leading from one or more states, inside a `From`.
@resultBuilder
public enum EventRuleBuilder<Event: Hashable & Sendable, State: Hashable & Sendable> {

    /// The events leading from the states.
    public typealias Events = [On<Event, State>]

    /// An event leading to a state.
    public static func buildExpression(_ on: On<Event, State>) -> Events {
        return [on]
    }

    /// All the events of a block together.
    public static func buildBlock(_ parts: Events...) -> Events {
        return parts.flatMap { $0 }
    }

    /// The events of an `if` without an `else`, or none when its condition is false.
    public static func buildOptional(_ events: Events?) -> Events {
        return events ?? []
    }

    /// The events of the first branch of an `if` or a `switch`.
    public static func buildEither(first events: Events) -> Events {
        return events
    }

    /// The events of the second branch of an `if` or a `switch`.
    public static func buildEither(second events: Events) -> Events {
        return events
    }

    /// The events of every round of a `for` loop together.
    public static func buildArray(_ parts: [Events]) -> Events {
        return parts.flatMap { $0 }
    }

    /// The events of an `if #available`.
    public static func buildLimitedAvailability(_ events: Events) -> Events {
        return events
    }
}

/// An event leading to a state, written inside a `From`, which tells the
/// states it leads from.
public struct On<Event: Hashable & Sendable, State: Hashable & Sendable>: Sendable {

    /// The trigger of the event.
    let event: Event

    /// The state the event leads to.
    let to: State

    /// Creates an event leading to a state.
    /// - Parameters:
    ///   - event: The trigger of the event.
    ///   - to: The state the event leads to.
    public init(_ event: Event, to: State) {
        self.event = event
        self.to = to
    }
}

/// The events leading from a state, or from every state but some, written
/// with `On`:
///
///     From(.hasCredit) {
///         On(.select, to: .drinkReady)
///         On(.cancel, to: .idle)
///     }
public struct From<Event: Hashable & Sendable, State: Hashable & Sendable>: Sendable {

    /// A rule for every event, from every state.
    let rules: Set<TransitionRule<Event, State>>

    /// Creates the rules for the events leading from a state.
    /// - Parameters:
    ///   - state: The state the events lead from.
    ///   - events: The events, each with the state it leads to.
    public init(_ state: State, @EventRuleBuilder<Event, State> _ events: () -> [On<Event, State>]) {
        self.rules = Set(events().map { TransitionRule(from: state, event: $0.event, to: $0.to) })
    }
}

extension From where State: CaseIterable {

    /// Creates the rules for the events leading from every state but some,
    /// like an event breaking a machine down at any state.
    ///
    /// Leave the state an event leads to out as well, unless it should lead
    /// back to itself. A state with a rule leading back to itself is not an
    /// ending state.
    /// - Parameters:
    ///   - excluded: The states without the rules.
    ///   - events: The events, each with the state it leads to.
    public init(allExcept excluded: Set<State>, @EventRuleBuilder<Event, State> _ events: () -> [On<Event, State>]) {
        let events = events()
        self.rules = Set(State.allCases.lazy.filter { !excluded.contains($0) }.flatMap { state in
            events.map { TransitionRule(from: state, event: $0.event, to: $0.to) }
        })
    }
}

/// An event at every state, leading back to the same state, like refilling
/// a machine without changing its state. No state is an ending state with it.
public struct AtEveryState<Event: Hashable & Sendable, State: Hashable & Sendable & CaseIterable>: Sendable {

    /// A rule at every state.
    let rules: Set<TransitionRule<Event, State>>

    /// Creates the rules for an event at every state.
    /// - Parameter event: The trigger of the event.
    public init(_ event: Event) {
        self.rules = TransitionRule.atEveryState(event: event)
    }
}
