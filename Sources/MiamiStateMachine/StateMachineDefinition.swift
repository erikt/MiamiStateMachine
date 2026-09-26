/// The definition of a state machine: its rules, kept in the forms the
/// questions about them need.
///
/// The rules are found by the state they lead from and their event, which is
/// how an event is processed, and by the state they lead to. The graph of the
/// states answers the questions about the definition as a whole. All of it is
/// made once, when the state machine is created, and never changes.
struct StateMachineDefinition<Event: Hashable & Sendable, State: Hashable & Sendable>: Sendable {

    /// Rules leading from the same state, for the same event, to different
    /// states. A definition with such rules is not consistent.
    struct Conflict: Error {
        let rules: Set<TransitionRule<Event, State>>
    }

    // MARK: - Private properties

    /// The rules by the state they lead from and their event.
    private let rulesByStateAndEvent: [State: [Event: TransitionRule<Event, State>]]

    /// The rules by the state they lead to.
    private let rulesByDestination: [State: Set<TransitionRule<Event, State>>]

    // MARK: - Properties

    /// All the rules, collected from the index. Made anew every time, for
    /// the snapshots of a state machine, which are not made often.
    var rules: Set<TransitionRule<Event, State>> {
        return Set(rulesByStateAndEvent.values.lazy.flatMap(\.values))
    }

    /// The number of rules.
    let ruleCount: Int

    /// The states, connected as the rules connect them.
    let graph: TransitionGraph<Event, State>

    // MARK: - Initialization

    /// Creates a definition from its rules.
    /// - Parameter rules: The rules defining the state machine.
    /// - Throws: The rules in conflict, if an event at a state leads to more
    /// than one state.
    init(rules: Set<TransitionRule<Event, State>>) throws(Conflict) {
        var rulesByStateAndEvent: [State: [Event: TransitionRule<Event, State>]] = [:]
        var rulesByDestination: [State: Set<TransitionRule<Event, State>>] = [:]
        var conflictingRules: Set<TransitionRule<Event, State>> = []

        for rule in rules {
            // A rule already found for the same state and event leads to another
            // state, as the rules are a set. The definition is then not consistent.
            let found = rulesByStateAndEvent[rule.from, default: [:]].updateValue(rule, forKey: rule.event)
            if let found {
                conflictingRules.insert(found)
                conflictingRules.insert(rule)
            }

            rulesByDestination[rule.to, default: []].insert(rule)
        }

        guard conflictingRules.isEmpty else {
            throw Conflict(rules: conflictingRules)
        }

        self.rulesByStateAndEvent = rulesByStateAndEvent
        self.rulesByDestination = rulesByDestination
        self.ruleCount = rules.count
        self.graph = TransitionGraph(transitions: rules)
    }

    // MARK: - Methods

    /// The rule for an event at a state, if there is one.
    /// - Complexity: O(1)
    func rule(from state: State, for event: Event) -> TransitionRule<Event, State>? {
        return rulesByStateAndEvent[state]?[event]
    }

    /// All rules leading from a state.
    /// - Complexity: O(*r*), where *r* is the number of rules returned.
    func rules(from state: State) -> Set<TransitionRule<Event, State>> {
        guard let rulesByEvent = rulesByStateAndEvent[state] else {
            return []
        }
        return Set(rulesByEvent.values)
    }

    /// All rules leading to a state.
    /// - Complexity: O(1)
    func rules(to state: State) -> Set<TransitionRule<Event, State>> {
        return rulesByDestination[state] ?? []
    }

    /// All events with a rule leading from a state.
    /// - Complexity: O(*r*), where *r* is the number of events returned.
    func events(from state: State) -> Set<Event> {
        guard let rulesByEvent = rulesByStateAndEvent[state] else {
            return []
        }
        return Set(rulesByEvent.keys)
    }

    /// If no rules lead from a state.
    /// - Complexity: O(1)
    func isEndingState(_ state: State) -> Bool {
        return rulesByStateAndEvent[state] == nil
    }
}
