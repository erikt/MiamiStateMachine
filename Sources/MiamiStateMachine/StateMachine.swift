import Foundation

/// A state machine is an actor with a current state and
/// a set of transitions defining the machine. The `TransitionRule`
/// connects two states by an event trigger.
///
/// An event is a `StateMachineEvent`. It can carry something, which the
/// state machine never looks at, but delivers with the `TransitionEvent`.
/// 
/// The state machine actor protects the current state from outside
/// modification. The state only changes by processing events.
/// 
/// Information about the definition of the state machine can be
/// accessed by non-isolated methods.
///
/// A state machine can own a context, of any type, for what the states alone
/// do not tell, like the credit of a vending machine. Only the actions of its
/// transitions change it. A state machine without one has `Void` as its context.
///
/// A state machine can be followed in Instruments, with the os_signpost
/// instrument. Every state is an interval, named by the state and ended by the
/// trigger of the event leaving it, and every rejected event is a signpost
/// event. Each state machine is a lane of its own. The signposts are only
/// written while Instruments records them, and cost next to nothing otherwise,
/// but they have to be asked for: add `MiamiStateMachine` to the subsystems
/// for dynamic tracing, in the recording options of the instrument. Events
/// are shown by their trigger, never with what they carry.
public actor StateMachine<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable> {

    // MARK: - Types

    /// A stream of the transitions made by a state machine.
    public typealias TransitionStream = AsyncStream<TransitionEvent<Event, State>>

    /// A stream of the events rejected by a state machine, each together
    /// with the state the state machine was at when rejecting the event.
    public typealias RejectedEventStream = AsyncStream<RejectedEvent<Event, State>>

    /// A stream of the states a state machine is at, one after the other.
    public typealias StateStream = AsyncStream<State>

    /// The reason a state machine cannot be created from a set of transitions.
    ///
    /// The transitions have to define a consistent state machine, where an
    /// event processed at a state leads to one single state. They do not
    /// when two or more of them lead from the same state, for the same
    /// event, to different states.
    public struct DefinitionError: Error, CustomStringConvertible {

        /// The transitions in conflict. For each one of them there is at
        /// least one other transition from the same state, for the same
        /// event, leading to another state.
        public let conflictingTransitions: Set<TransitionRule<Event.EventTrigger, State>>

        public var description: String {
            // Sorted, as the same error should have the same description every time.
            let conflicts = conflictingTransitions.map { "\($0)" }.sorted().joined(separator: ", ")
            return "The transitions do not define a consistent state machine. "
                + "The same event leads from the same state to different states: \(conflicts)"
        }
    }

    /// The reason a state machine cannot be restored from a snapshot.
    ///
    /// A snapshot fits the rules when every rule it was made with is still one
    /// of them. Rules added since keep it fitting, while a rule removed, or
    /// changed to lead to another state, makes it a snapshot of another state
    /// machine. Problems with the saved data itself, like a state or a context
    /// that no longer decodes, are thrown by the decoder, before restoring.
    public enum RestoreError: Error, CustomStringConvertible {

        /// The rules given conflict, as for any state machine.
        case conflictingRules(DefinitionError)

        /// The snapshot was made with rules that are no longer among the rules
        /// given. It holds the rules missing.
        case incompatibleSnapshot(missingRules: Set<TransitionRule<Event.EventTrigger, State>>)

        public var description: String {
            switch self {
            case .conflictingRules(let error):
                return error.description
            case .incompatibleSnapshot(let missingRules):
                // Sorted, as the same error should have the same description every time.
                let missing = missingRules.map { "\($0)" }.sorted().joined(separator: ", ")
                return "The snapshot was made with rules that are no longer part of the "
                    + "definition: \(missing)"
            }
        }
    }

    // MARK: - Internal and private properties

    // Internal where the extensions in the other files of the state machine
    // need them: the streams, the waiting and the questions.

    /// The definition of the state machine: its rules, kept in the forms the
    /// questions about them need.
    let definition: StateMachineDefinition<Event.EventTrigger, State>

    /// The transition streams in use.
    var transitionStreams = StreamRegistry<TransitionEvent<Event, State>>()

    /// The rejected event streams in use.
    var rejectedEventStreams = StreamRegistry<RejectedEvent<Event, State>>()

    /// The state streams in use.
    var stateStreams = StreamRegistry<State>()

    /// The signposts showing the state machine in Instruments.
    private var signposts = StateSignposts<State>()

    /// The actions of the rules having any, in the order they were written.
    private let actions: [TransitionRule<Event.EventTrigger, State>: [TransitionAction<Event, State, Context>]]

    // MARK: - Public nonisolated properties

    /// The starting state for the state machine. It is part of the
    /// definition, and can be read without waiting for the state machine.
    public nonisolated let initialState: State

    // MARK: - Public isolated properties

    /// The current state of the state machine.
    public private(set) var state: State

    /// The context of the state machine, for what the states alone do not
    /// tell. Only the actions of the transitions change it, as part of the
    /// transition, so it always agrees with `state`.
    public private(set) var context: Context

    /// A log keeping track of all processed transitions
    /// of the state machine. The log has a max capacity of
    /// transitions it keeps track of. When the max capacity
    /// has been reached, it throws away the oldest log
    /// entry.
    ///
    /// The log is a collection of the transitions made, from the
    /// oldest to the newest.
    ///
    /// The log keeps the events with what they carry. Without a max capacity
    /// everything ever carried is kept for as long as the state machine is, so
    /// give the log a capacity when events carry something of size.
    public private(set) var transitionLog: CapacityLog<TransitionEvent<Event, State>>

    /// Number of events processed. Includes events that
    /// did not lead to a state change for the state machine.
    public private(set) var processedEventsCount: Int = 0
    
    /// Counter for the number of state changes for this state machine.
    public private(set) var stateChangeCount: Int = 0
    
    /// The transition that led to the current state. It is nil until the
    /// first transition is made.
    ///
    /// The transition is kept apart from the transition log, so it is
    /// also known by a state machine with a log capacity of zero. Its
    /// event is kept with what it carries, until the next transition.
    public private(set) var enteredWith: TransitionEvent<Event, State>?

    /// When the current state was entered, by the transition in `enteredWith`.
    /// Until the first transition it is when the state machine was created.
    ///
    /// Every transition sets it, also one leading back to the same state,
    /// and a rejected event does not. The time spent at the current state
    /// so far is `ContinuousClock.now - enteredAt`.
    ///
    /// The instant is of the continuous clock, which goes on while the device
    /// sleeps. It only means something in the process it was read in, so keep
    /// it for measuring, not for saving.
    public private(set) var enteredAt: ContinuousClock.Instant

    // MARK: - Computed properties

    /// Counter for the number of events processed that did
    /// not lead to a state change.
    public var rejectedEventsCount: Int {
        return processedEventsCount - stateChangeCount
    }
    
    /// If the state machine is at its initial state and has not
    /// made any transition since its creation. A transition leading
    /// back to the initial state counts as a transition made.
    public var isAtInitialState: Bool {
        return state == initialState && stateChangeCount == 0
    }

    /// If the state machine is at an ending state. No transitions
    /// lead from an ending state, so no further events will be accepted.
    ///
    /// A state with a transition leading back to the same state
    /// is not an ending state.
    public var isAtEndingState: Bool {
        return isEndingState(state)
    }
    
    // MARK: - Initialization
    
    /// Creates a new state machine, with a context.
    ///
    /// The transitions have to define a consistent state machine, where an
    /// event processed at a state leads to one single state. Several events
    /// can lead from a state to the same state, and the same event can be
    /// used from several states.
    ///
    /// Any initial state is accepted, also a state without transitions
    /// leading from it. Such a state machine is at an ending state from
    /// the start, and rejects every event.
    ///
    /// The transitions are written in event triggers, which does not tell the
    /// type of the events, so it has to be written: `StateMachine<LoadEvent,
    /// LoadState, Progress>(transitions:initialState:context:)`. It is known
    /// from the transitions only for events being their own trigger.
    ///
    /// Transitions given as a set have no actions, so the context stays as it
    /// is given. Actions are written with the rule builder.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - context: Initial context for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if two
    /// or more transitions lead from the same state, for the same event,
    /// to different states.
    public init(transitions: Set<TransitionRule<Event.EventTrigger, State>>,
                initialState: State,
                context: Context,
                logCapacity: UInt? = nil) throws(DefinitionError)
    {
        try self.init(definedBy: TransitionRules(transitions), initialState: initialState, context: context, logCapacity: logCapacity)
    }

    /// Creates a state machine. It is what the other initializers do, which
    /// have the same names for their parameters, and cannot call each other.
    private init(definedBy rules: TransitionRules<Event, State, Context>,
                 initialState: State,
                 context: Context,
                 logCapacity: UInt?) throws(DefinitionError)
    {
        do {
            self.definition = try StateMachineDefinition(rules: rules.rules)
        } catch {
            throw DefinitionError(conflictingTransitions: error.rules)
        }

        self.actions = rules.actions
        self.transitionLog = CapacityLog(capacity: logCapacity)
        self.initialState = initialState
        self.state = initialState
        self.context = context
        self.enteredAt = .now
        signposts.enter(initialState)
    }

    /// Creates a state machine restored from a snapshot. It is what the
    /// restoring initializers do.
    /// - Parameters:
    ///   - rules: The rules defining the state machine, with their actions.
    ///   - initialState: Initial state for the state machine.
    ///   - snapshot: The snapshot to restore.
    ///   - logCapacity: Max capacity of transition log.
    /// - Throws: A `RestoreError`, if the rules conflict, or the snapshot
    /// was made with rules that are no longer among them.
    private init(definedBy rules: TransitionRules<Event, State, Context>,
                 initialState: State,
                 restoring snapshot: Snapshot,
                 logCapacity: UInt?) throws(RestoreError)
    {
        do {
            self.definition = try StateMachineDefinition(rules: rules.rules)
        } catch {
            throw .conflictingRules(DefinitionError(conflictingTransitions: error.rules))
        }

        // Rules added since the snapshot are fine, and missing ones are not.
        let missingRules = snapshot.rules.subtracting(rules.rules)
        guard missingRules.isEmpty else {
            throw .incompatibleSnapshot(missingRules: missingRules)
        }

        // The capacity is the one given, keeping the newest of the saved transitions.
        var transitionLog = CapacityLog<TransitionEvent<Event, State>>(capacity: logCapacity)
        for transition in snapshot.transitionLog {
            transitionLog.append(transition)
        }

        self.actions = rules.actions
        self.transitionLog = transitionLog
        self.initialState = initialState
        self.state = snapshot.state
        self.context = snapshot.context
        self.processedEventsCount = snapshot.processedEventsCount
        self.stateChangeCount = snapshot.stateChangeCount
        self.enteredWith = snapshot.enteredWith
        self.enteredAt = .now
        signposts.enter(snapshot.state)
    }

    deinit {
        // Finish the streams still in use. Their consumers
        // would otherwise be left waiting forever.
        transitionStreams.finishAll()
        rejectedEventStreams.finishAll()
        stateStreams.finishAll()
        signposts.end()
    }

    // MARK: - API methods

    /// Process an event.
    ///
    /// If there is a transition from the current state for the event, the
    /// event is accepted and the state machine makes the transition.
    /// Otherwise the event is rejected, and nothing changes.
    ///
    /// The transition returned is what this event led to, also when other
    /// tasks are processing events at the same time. Reading `state` after
    /// processing an event tells where the state machine is by then, which
    /// can be somewhere else.
    ///
    /// - Parameters:
    ///   - event: Event to process.
    /// - Returns: The transition made, or nil if the event was rejected.
    @discardableResult
    public func process(_ event: Event) -> TransitionEvent<Event, State>? {

        // Increase the counter for the number of processed events
        // by the state machine. This includes events process that
        // did not lead to a state change.
        processedEventsCount += 1

        // The transition is found by the trigger of the event. What the
        // event carries is not looked at, only delivered with the event.
        guard let t = transition(from: state, for: event.eventTrigger) else {
            signposts.reject(event.eventTrigger, at: state)
            rejectedEventStreams.yield(RejectedEvent(event: event, state: state))
            return nil
        }

        let made = TransitionEvent(from: t.from, event: event, to: t.to)
        signposts.leave(by: t.event)
        signposts.enter(t.to)
        commit(made)
        if !actions.isEmpty, let actionsOfRule = actions[t] {
            // Part of the transition: nothing comes in between, and the
            // streams deliver the transition with the context changed.
            for action in actionsOfRule {
                action(&context, made)
            }
        }
        transitionStreams.yield(made)
        stateStreams.yield(state)
        if isAtEndingState {
            // No further transitions will be made.
            transitionStreams.finishAll()
            stateStreams.finishAll()
        }
        return made
    }

    /// Process an event, and throw if it is rejected.
    ///
    /// It is `process(_:)`, for when a rejected event is an error. The event
    /// is processed the same way: a rejected event is counted, and delivered
    /// by the streams of rejected events, before it is thrown.
    ///
    ///     do {
    ///         let transition = try await stateMachine.processOrThrow(.pay)
    ///     } catch {
    ///         print("\(error.event) was rejected at \(error.state)")
    ///     }
    ///
    /// - Parameters:
    ///   - event: Event to process.
    /// - Returns: The transition made.
    /// - Throws: The event as a `RejectedEvent`, with the state it was
    /// rejected at, if there is no transition for it from the current state.
    @discardableResult
    public func processOrThrow(_ event: Event) throws(RejectedEvent<Event, State>) -> TransitionEvent<Event, State> {
        guard let made = process(event) else {
            // A rejected event changes nothing, so the state
            // machine is still at the state rejecting it.
            throw RejectedEvent(event: event, state: state)
        }
        return made
    }

    // MARK: - Private methods
    
    /// Commit transition. Change the current state to the to-state
    /// in the transition and keep track of processed and accepted
    /// transitions in a stack.
    /// - Parameter transition: State machine accepted transition.
    private func commit(_ transition: TransitionEvent<Event, State>) {
        state = transition.to
        enteredWith = transition
        enteredAt = .now
        transitionLog.append(transition)
        stateChangeCount += 1
    }

}

// MARK: - Events being their own trigger

extension StateMachine where Event.EventTrigger == Event {

    /// Creates a state machine with a context, for events being their own
    /// trigger, which events without anything to carry are. The type of the
    /// events is then known from the transitions, and does not have to be written.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - context: Initial context for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public init(transitions: Set<TransitionRule<Event, State>>,
                initialState: State,
                context: Context,
                logCapacity: UInt? = nil) throws(DefinitionError)
    {
        try self.init(definedBy: TransitionRules(transitions), initialState: initialState, context: context, logCapacity: logCapacity)
    }
}

// MARK: - Without a context

extension StateMachine where Context == Void {

    /// Creates a new state machine without a context.
    ///
    /// The transitions have to define a consistent state machine, where an
    /// event processed at a state leads to one single state. See
    /// `init(transitions:initialState:context:logCapacity:)`.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if two
    /// or more transitions lead from the same state, for the same event,
    /// to different states.
    public init(transitions: Set<TransitionRule<Event.EventTrigger, State>>,
                initialState: State,
                logCapacity: UInt? = nil) throws(DefinitionError)
    {
        try self.init(definedBy: TransitionRules(transitions), initialState: initialState, context: (), logCapacity: logCapacity)
    }

    /// Creates a state machine without a context, from rules written state
    /// by state. See `init(initialState:context:logCapacity:rules:)`.
    /// - Parameters:
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    ///   - rules: The rules defining the state machine, in event triggers.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// rules do not define a consistent state machine.
    public init(initialState: State,
                logCapacity: UInt? = nil,
                @TransitionRuleBuilder<Event, State, Context> rules: @Sendable () -> TransitionRules<Event, State, Context>) throws(DefinitionError)
    {
        try self.init(definedBy: rules(), initialState: initialState, context: (), logCapacity: logCapacity)
    }
}

extension StateMachine where Event.EventTrigger == Event, Context == Void {

    /// Creates a state machine without a context, for events being their own
    /// trigger. The type of the events is then known from the transitions.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public init(transitions: Set<TransitionRule<Event, State>>,
                initialState: State,
                logCapacity: UInt? = nil) throws(DefinitionError)
    {
        try self.init(definedBy: TransitionRules(transitions), initialState: initialState, context: (), logCapacity: logCapacity)
    }
}

// MARK: - Rules built state by state

extension StateMachine {

    /// Creates a state machine with a context, from rules written state by
    /// state, with the events leading from each state, and the actions
    /// changing the context when their transitions are made:
    ///
    ///     let machine = try StateMachine<CoinEvent, CoinState, Credit>(initialState: .idle, context: Credit()) {
    ///         From(.idle) {
    ///             On(.insert, to: .hasCredit) { credit, transition in
    ///                 if case .insert(let cents) = transition.event {
    ///                     credit.cents += cents
    ///                 }
    ///             }
    ///         }
    ///     }
    ///
    /// The types of the events, the states and the context have to be written,
    /// as they cannot be inferred from the rules. See `TransitionRuleBuilder`
    /// for everything the rules can be written with.
    ///
    /// The rules are given to the state machine, an actor, so the closure
    /// writing them is `Sendable`, and can be written on the main actor too.
    /// There, copy what it needs from a class, like a view model, into a
    /// constant before, and use the constant.
    /// - Parameters:
    ///   - initialState: Initial state for the state machine.
    ///   - context: Initial context for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    ///   - rules: The rules defining the state machine, in event triggers.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// rules do not define a consistent state machine.
    public init(initialState: State,
                context: Context,
                logCapacity: UInt? = nil,
                @TransitionRuleBuilder<Event, State, Context> rules: @Sendable () -> TransitionRules<Event, State, Context>) throws(DefinitionError)
    {
        try self.init(definedBy: rules(), initialState: initialState, context: context, logCapacity: logCapacity)
    }
}

// MARK: - Restored from a snapshot

extension StateMachine {

    /// Creates a state machine restored from a snapshot of another one, made
    /// with the same rules or fewer, with its state, context, transition log
    /// and counts. Everything else comes from the arguments, as when creating
    /// a new state machine: the rules, the initial state and the log capacity.
    ///
    ///     let saved = try JSONDecoder().decode(OrderStateMachine.Snapshot.self, from: data)
    ///     let stateMachine: OrderStateMachine
    ///     do {
    ///         stateMachine = try StateMachine(transitions: rules, initialState: .cart, restoring: saved)
    ///     } catch .incompatibleSnapshot {
    ///         // The rules have changed since the snapshot was made: start over.
    ///         stateMachine = try StateMachine(transitions: rules, initialState: .cart)
    ///     }
    ///
    /// The snapshot fits the rules when every rule it was made with is still
    /// one of them. The initial state can have changed, and it is not at the
    /// initial state unless the snapshot was made before any transition.
    ///
    /// When the state was entered is not saved, as an instant only means
    /// something in the process it was read in, so `enteredAt` is when the
    /// state machine was restored. Transitions given as a set have no actions.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - snapshot: The snapshot to restore.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. A saved log with more entries
    ///   keeps the newest.
    /// - Throws: A `RestoreError`, if the transitions conflict, or the snapshot
    /// was made with rules that are no longer among them.
    public init(transitions: Set<TransitionRule<Event.EventTrigger, State>>,
                initialState: State,
                restoring snapshot: Snapshot,
                logCapacity: UInt? = nil) throws(RestoreError)
    {
        try self.init(definedBy: TransitionRules(transitions), initialState: initialState, restoring: snapshot, logCapacity: logCapacity)
    }

    /// Creates a state machine restored from a snapshot of another one, from
    /// rules written state by state, with their actions, which go on changing
    /// the restored context. See `init(transitions:initialState:restoring:logCapacity:)`.
    /// - Parameters:
    ///   - initialState: Initial state for the state machine.
    ///   - snapshot: The snapshot to restore.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. A saved log with more entries
    ///   keeps the newest.
    ///   - rules: The rules defining the state machine, in event triggers.
    /// - Throws: A `RestoreError`, if the rules conflict, or the snapshot was
    /// made with rules that are no longer among them.
    public init(initialState: State,
                restoring snapshot: Snapshot,
                logCapacity: UInt? = nil,
                @TransitionRuleBuilder<Event, State, Context> rules: @Sendable () -> TransitionRules<Event, State, Context>) throws(RestoreError)
    {
        try self.init(definedBy: rules(), initialState: initialState, restoring: snapshot, logCapacity: logCapacity)
    }
}

// MARK: - Definition error

extension StateMachine.DefinitionError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}

// MARK: - Restore error

extension StateMachine.RestoreError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
