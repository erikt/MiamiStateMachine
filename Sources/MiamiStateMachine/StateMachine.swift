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
/// A state machine can be followed in Instruments, with the os_signpost
/// instrument. Every state is an interval, named by the state and ended by the
/// trigger of the event leaving it, and every rejected event is a signpost
/// event. Each state machine is a lane of its own. The signposts are only
/// written while Instruments records them, and cost next to nothing otherwise,
/// but they have to be asked for: add `MiamiStateMachine` to the subsystems
/// for dynamic tracing, in the recording options of the instrument. Events
/// are shown by their trigger, never with what they carry.
public actor StateMachine<Event: StateMachineEvent, State: Hashable & Sendable> {

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

    // MARK: - Public nonisolated properties

    /// The starting state for the state machine. It is part of the
    /// definition, and can be read without waiting for the state machine.
    public nonisolated let initialState: State

    // MARK: - Public isolated properties

    /// The current state of the state machine.
    public private(set) var state: State

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
    
    /// Creates a new state machine.
    ///
    /// The transitions have to define a consistent state machine, where an
    /// event processed at a state leads to one single state. Several events
    /// can lead from a state to the same state, and the same event can be
    /// used from several states.
    ///
    /// Any initial state is accepted, also a state without transitions
    /// leading from it. Such a state machine is at an ending state from
    /// the start, and rejects every event.
    /// The transitions are written in event triggers, which does not tell the
    /// type of the events, so it has to be written: `StateMachine<LoadEvent,
    /// LoadState>(transitions:initialState:)`. It is known from the transitions
    /// only for events being their own trigger.
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
        try self.init(definedBy: transitions, initialState: initialState, logCapacity: logCapacity)
    }

    /// Creates a state machine. It is what the other initializers do, which
    /// have the same names for their parameters, and cannot call each other.
    private init(definedBy transitions: Set<TransitionRule<Event.EventTrigger, State>>,
                 initialState: State,
                 logCapacity: UInt?) throws(DefinitionError)
    {
        do {
            self.definition = try StateMachineDefinition(rules: transitions)
        } catch {
            throw DefinitionError(conflictingTransitions: error.rules)
        }

        self.transitionLog = CapacityLog(capacity: logCapacity)
        self.initialState = initialState
        self.state = initialState
        self.enteredAt = .now
        signposts.enter(initialState)
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

    /// Creates a state machine for events being their own trigger, which
    /// events without anything to carry are. The type of the events is
    /// then known from the transitions, and does not have to be written.
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
        try self.init(definedBy: transitions, initialState: initialState, logCapacity: logCapacity)
    }
}

// MARK: - Rules built state by state

extension StateMachine {

    /// Creates a state machine from rules written state by state, with the
    /// events leading from each state:
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
    /// The types of the events and the states have to be written, as they
    /// cannot be inferred from the rules. See `TransitionRuleBuilder` for
    /// everything the rules can be written with.
    ///
    /// The rules are given to the state machine, an actor, so the closure
    /// writing them is `Sendable`, and can be written on the main actor too.
    /// There, copy what it needs from a class, like a view model, into a
    /// constant before, and use the constant.
    /// - Parameters:
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    ///   - rules: The rules defining the state machine, in event triggers.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// rules do not define a consistent state machine.
    public init(initialState: State,
                logCapacity: UInt? = nil,
                @TransitionRuleBuilder<Event.EventTrigger, State> rules: @Sendable () -> Set<TransitionRule<Event.EventTrigger, State>>) throws(DefinitionError)
    {
        try self.init(transitions: rules(), initialState: initialState, logCapacity: logCapacity)
    }
}

// MARK: - Definition error

extension StateMachine.DefinitionError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}
