/// An action of a transition: what it does to the context of the state
/// machine. It is given the context to change, and the transition made, with
/// the event and what it carries.
public typealias TransitionAction<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable>
    = @Sendable (inout Context, TransitionEvent<Event, State>) -> Void

/// The rules of a state machine, and the actions of some of them, as written
/// with the rule builder.
///
/// The rules are plain values, and the actions are kept beside them, so the
/// rules can still be compared, saved and checked. A rule written several
/// times with actions has all of them, run in the order they were written.
public struct TransitionRules<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable>: Sendable {

    /// A rule, written in event triggers.
    public typealias Rule = TransitionRule<Event.EventTrigger, State>

    /// The rules.
    public private(set) var rules: Set<Rule>

    /// The actions of the rules having any, in the order they were written.
    private(set) var actions: [Rule: [TransitionAction<Event, State, Context>]]

    /// Creates rules without actions.
    /// - Parameter rules: The rules.
    public init(_ rules: Set<Rule> = []) {
        self.rules = rules
        self.actions = [:]
    }

    /// Creates a rule with an action.
    /// - Parameters:
    ///   - rule: The rule.
    ///   - action: What the transition of the rule does to the context.
    init(_ rule: Rule, action: TransitionAction<Event, State, Context>?) {
        self.rules = [rule]
        self.actions = action.map { [rule: [$0]] } ?? [:]
    }

    /// Adds other rules and their actions, after the actions already here.
    /// - Parameter other: The rules to add.
    mutating func formUnion(_ other: TransitionRules) {
        rules.formUnion(other.rules)
        actions.merge(other.actions) { $0 + $1 }
    }
}

/// Builds the rules of a state machine, state by state, with the events
/// leading from each state, and what their transitions do to the context:
///
///     let machine = try StateMachine<CoinEvent, CoinState, Credit>(initialState: .idle, context: Credit()) {
///         From(.idle) {
///             On(.insert, to: .hasCredit) { credit, transition in
///                 if case .insert(let cents) = transition.event {
///                     credit.cents += cents
///                 }
///             }
///         }
///         From(.hasCredit) {
///             On(.cancel, to: .idle) { credit, _ in
///                 credit.cents = 0
///             }
///         }
///     }
///
/// Besides `From`, the rules can be given as `AtEveryState`, as a single
/// `TransitionRule`, as a set of them, or as `TransitionRules` built before.
/// `if`, `switch` and `for` can be used as in any other code.
///
/// The rules are written in event triggers, as a definition always is. The
/// types of the events, the states and the context cannot be inferred from
/// the rules, so they have to be written.
///
/// Conflicting rules are found when the state machine is created, as for
/// any other rules.
@resultBuilder
public enum TransitionRuleBuilder<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable> {

    /// The rules built.
    public typealias Rules = TransitionRules<Event, State, Context>

    // MARK: - Expressions

    /// The rules for the events leading from one or more states.
    public static func buildExpression(_ from: From<Event, State, Context>) -> Rules {
        return from.rules
    }

    /// A single rule, without an action.
    public static func buildExpression(_ rule: TransitionRule<Event.EventTrigger, State>) -> Rules {
        return Rules([rule])
    }

    /// A set of rules without actions, like the ones made by `TransitionRule.from(allExcept:event:to:)`.
    public static func buildExpression(_ rules: Set<TransitionRule<Event.EventTrigger, State>>) -> Rules {
        return Rules(rules)
    }

    /// Rules built before, with their actions.
    public static func buildExpression(_ rules: Rules) -> Rules {
        return rules
    }

    // MARK: - Blocks

    /// All the rules of a block together, with their actions in the order written.
    public static func buildBlock(_ parts: Rules...) -> Rules {
        return parts.reduce(into: Rules()) { $0.formUnion($1) }
    }

    /// The rules of an `if` without an `else`, or none when its condition is false.
    public static func buildOptional(_ rules: Rules?) -> Rules {
        return rules ?? Rules()
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
        return parts.reduce(into: Rules()) { $0.formUnion($1) }
    }

    /// The rules of an `if #available`.
    public static func buildLimitedAvailability(_ rules: Rules) -> Rules {
        return rules
    }
}

extension TransitionRuleBuilder where State: CaseIterable {

    /// The rules for an event at every state, leading back to the same state.
    public static func buildExpression(_ stay: AtEveryState<Event, State, Context>) -> Rules {
        return stay.rules
    }
}

/// Builds the events leading from one or more states, inside a `From`.
@resultBuilder
public enum EventRuleBuilder<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable> {

    /// The events leading from the states.
    public typealias Events = [On<Event, State, Context>]

    /// An event leading to a state.
    public static func buildExpression(_ on: On<Event, State, Context>) -> Events {
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
/// states it leads from. It can have an action, changing the context of the
/// state machine when the transition is made.
public struct On<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable>: Sendable {

    /// The trigger of the event.
    let event: Event.EventTrigger

    /// The state the event leads to.
    let to: State

    /// What the transition does to the context, if anything.
    let action: TransitionAction<Event, State, Context>?

    /// Creates an event leading to a state.
    /// - Parameters:
    ///   - event: The trigger of the event.
    ///   - to: The state the event leads to.
    public init(_ event: Event.EventTrigger, to: State) {
        self.event = event
        self.to = to
        self.action = nil
    }

    /// Creates an event leading to a state, with an action changing the
    /// context of the state machine when the transition is made.
    ///
    /// The action runs as part of the transition, after the state has changed
    /// and before the streams deliver the transition, with nothing coming in
    /// between. It is given the transition, with the event and what it carries.
    /// - Parameters:
    ///   - event: The trigger of the event.
    ///   - to: The state the event leads to.
    ///   - action: What the transition does to the context.
    public init(_ event: Event.EventTrigger, to: State, action: @escaping TransitionAction<Event, State, Context>) {
        self.event = event
        self.to = to
        self.action = action
    }
}

/// The events leading from a state, or from every state but some, written
/// with `On`:
///
///     From(.hasCredit) {
///         On(.select, to: .drinkReady)
///         On(.cancel, to: .idle)
///     }
public struct From<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable>: Sendable {

    /// A rule for every event, from every state, with the actions.
    let rules: TransitionRules<Event, State, Context>

    /// Creates the rules for the events leading from a state.
    /// - Parameters:
    ///   - state: The state the events lead from.
    ///   - events: The events, each with the state it leads to.
    public init(_ state: State, @EventRuleBuilder<Event, State, Context> _ events: () -> [On<Event, State, Context>]) {
        self.rules = Self.rules(from: [state], for: events())
    }

    /// The rules for events leading from states, in the order written.
    /// - Parameters:
    ///   - states: The states the events lead from.
    ///   - events: The events.
    /// - Returns: A rule for every event from every state, with the actions.
    static func rules(from states: some Sequence<State>, for events: [On<Event, State, Context>]) -> TransitionRules<Event, State, Context> {
        var rules = TransitionRules<Event, State, Context>()
        for state in states {
            for on in events {
                rules.formUnion(TransitionRules(TransitionRule(from: state, event: on.event, to: on.to), action: on.action))
            }
        }
        return rules
    }
}

extension From where State: CaseIterable {

    /// Creates the rules for the events leading from every state but some,
    /// like an event breaking a machine down at any state. An action is the
    /// action of the event from every one of the states.
    ///
    /// Leave the state an event leads to out as well, unless it should lead
    /// back to itself. A state with a rule leading back to itself is not an
    /// ending state.
    /// - Parameters:
    ///   - excluded: The states without the rules.
    ///   - events: The events, each with the state it leads to.
    public init(allExcept excluded: Set<State>, @EventRuleBuilder<Event, State, Context> _ events: () -> [On<Event, State, Context>]) {
        self.rules = Self.rules(from: State.allCases.filter { !excluded.contains($0) }, for: events())
    }
}

/// An event at every state, leading back to the same state, like refilling
/// a machine without changing its state. No state is an ending state with it.
public struct AtEveryState<Event: StateMachineEvent, State: Hashable & Sendable & CaseIterable, Context: Sendable>: Sendable {

    /// A rule at every state, with the action.
    let rules: TransitionRules<Event, State, Context>

    /// Creates the rules for an event at every state.
    /// - Parameter event: The trigger of the event.
    public init(_ event: Event.EventTrigger) {
        self.rules = TransitionRules(TransitionRule.atEveryState(event: event))
    }

    /// Creates the rules for an event at every state, with an action changing
    /// the context of the state machine, like filling a machine up.
    /// - Parameters:
    ///   - event: The trigger of the event.
    ///   - action: What the transition does to the context, at every state.
    public init(_ event: Event.EventTrigger, action: @escaping TransitionAction<Event, State, Context>) {
        var rules = TransitionRules<Event, State, Context>()
        for state in State.allCases {
            rules.formUnion(TransitionRules(TransitionRule(from: state, event: event, to: state), action: action))
        }
        self.rules = rules
    }
}
