/// A rule of the definition of a state machine: the transition from a state,
/// for an event, to another state. A rule only leads in one direction.
///
/// A rule can be encoded when its event and states can, and decoded
/// when they can be decoded. The keys are `from`, `event` and `to`.
public struct TransitionRule<Event: Hashable & Sendable, State: Hashable & Sendable> {
    
    /// The transition from state.
    public let from: State
    
    /// The event connecting the from state with the to state.
    public let event: Event
    
    /// The transition to state.
    public let to: State
    
    /// Create a transition from a state to another state,
    /// connected by an event.
    /// - Parameters:
    ///   - from: The from state.
    ///   - event: The event connecting the states.
    ///   - to: The to state.
    public init(from: State, event: Event, to: State) {
        self.from = from
        self.event = event
        self.to = to
    }
}

extension TransitionRule: Sendable { }
extension TransitionRule: Equatable { }
extension TransitionRule: Hashable { }
extension TransitionRule: Encodable where Event: Encodable, State: Encodable { }
extension TransitionRule: Decodable where Event: Decodable, State: Decodable { }

extension TransitionRule: CustomStringConvertible {
    public var description: String {
        return "\(from) --(\(event))--> \(to)"
    }
}


// MARK: - Rules for many states

extension TransitionRule where State: CaseIterable {

    /// Rules for the same event from every state but some, all leading to the
    /// same state. They are ordinary rules, to put together with the rest of
    /// the definition, like an event breaking a machine down at any state.
    ///
    ///     let rules: Set<TransitionRule<VendingEvent, VendingState>> = [
    ///         TransitionRule(from: .idle, event: .insertCoin, to: .hasCredit),
    ///     ]
    ///     let definition = rules
    ///         .union(TransitionRule.from(allExcept: [.outOfOrder], event: .breakDown, to: .outOfOrder))
    ///
    /// The rules are put together with a set of a declared type, which tells
    /// the types of the events and the states.
    ///
    /// Leave the state led to out as well, unless it should lead back to
    /// itself. A state with a rule leading back to itself is not an ending
    /// state. A rule that conflicts with another rule of the definition is
    /// found when the state machine is created, like any other.
    /// - Parameters:
    ///   - excluded: The states without the rule.
    ///   - event: The event of every rule.
    ///   - to: The state every rule leads to.
    /// - Returns: A rule from every state of the type but the excluded ones.
    public static func from(allExcept excluded: Set<State>, event: Event, to: State) -> Set<TransitionRule> {
        return Set(State.allCases.lazy
            .filter { !excluded.contains($0) }
            .map { TransitionRule(from: $0, event: event, to: to) })
    }

    /// Rules for the same event at every state, each leading back to the
    /// state it is from, like refilling a machine without changing its state.
    ///
    ///     let rules = TransitionRule<VendingEvent, VendingState>.atEveryState(event: .refill)
    ///
    /// No state is an ending state with these rules, as every state has a
    /// rule leading back to itself.
    /// - Parameter event: The event of every rule.
    /// - Returns: A rule from every state of the type back to itself.
    public static func atEveryState(event: Event) -> Set<TransitionRule> {
        return Set(State.allCases.map { TransitionRule(from: $0, event: event, to: $0) })
    }
}
