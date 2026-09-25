import MiamiStateMachine
import Observation

/// A state machine for a user interface. It has the current state of a
/// `StateMachine` as an observable property on the main actor, so a SwiftUI
/// view using `state` is updated when the state machine makes a transition.
///
///     struct DoorView: View {
///         @State private var door: ObservableStateMachine<DoorEvent, DoorState, Void>
///
///         var body: some View {
///             Text("The door is \(String(describing: door.state))")
///
///             Button("Open") {
///                 door.send(.open)
///             }
///             .disabled(door.accepts(.open) == false)
///         }
///     }
///
/// The state machine is still the one deciding. Events are sent to it, and
/// `state` follows what it does. The same state machine can be used by other
/// parts of an app at the same time, and `state` follows their events as well.
///
/// `state` is what was last heard from the state machine, which can have
/// moved on. Use `process(_:)` to know what an event led to, and the state
/// machine itself, by `stateMachine`, for anything else the observable state
/// machine lacks.
@MainActor
@Observable
public final class ObservableStateMachine<Event: StateMachineEvent, State: Hashable & Sendable, Context: Sendable> {

    // MARK: - Public properties

    /// The state machine being observed.
    public let stateMachine: StateMachine<Event, State, Context>

    /// The current state, as last heard from the state machine.
    ///
    /// It is the initial state until the state machine has been heard from,
    /// which is a moment after the observable state machine is created.
    ///
    /// Only the newest state is kept for the main actor. If the state machine
    /// makes several transitions before the main actor has time for them, the
    /// states in between are never seen here. Every state is delivered by
    /// `stateStream()` of the state machine.
    public private(set) var state: State

    // MARK: - Private properties

    /// The events sent, waiting to be processed by the state machine.
    @ObservationIgnored
    private let sentEvents: AsyncStream<SentEvent>.Continuation

    /// The task following the states of the state machine.
    @ObservationIgnored
    private var following: Task<Void, Never>?

    // MARK: - Computed properties

    /// All event triggers the state machine accepts at the current state.
    public var eventsFromCurrent: Set<Event.EventTrigger> {
        stateMachine.events(from: state)
    }

    /// If the state machine is at an ending state, where no events are accepted.
    public var isAtEndingState: Bool {
        stateMachine.isEndingState(state)
    }

    // MARK: - Initialization

    /// Creates an observable state machine following a state machine.
    /// - Parameter stateMachine: The state machine to observe. It can be
    /// in use already, and be used by others at the same time.
    public init(_ stateMachine: StateMachine<Event, State, Context>) {
        self.stateMachine = stateMachine
        self.state = stateMachine.initialState

        // A task for every event could get the events to the state machine in
        // another order than they were sent. One task taking them from a
        // stream keeps the order. It ends when the stream is finished.
        let (events, sentEvents) = AsyncStream.makeStream(of: SentEvent.self)
        self.sentEvents = sentEvents
        Task {
            for await sent in events {
                let transition = await stateMachine.process(sent.event)
                sent.waiting?.resume(returning: transition)
            }
        }

        // Only where the state machine is now is of interest, not the states
        // it passed while the main actor was busy.
        self.following = Task { [weak self] in
            let states = await stateMachine.stateStream(bufferingPolicy: .bufferingNewest(1))
            for await state in states {
                self?.state = state
            }
        }
    }

    /// Creates an observable state machine with a new state machine, with a
    /// context. Transitions given as a set have no actions.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - context: Initial context for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public convenience init(transitions: Set<TransitionRule<Event.EventTrigger, State>>,
                            initialState: State,
                            context: Context,
                            logCapacity: UInt? = nil) throws(StateMachine<Event, State, Context>.DefinitionError)
    {
        self.init(try StateMachine(transitions: transitions, initialState: initialState, context: context, logCapacity: logCapacity))
    }

    /// Creates an observable state machine with a new state machine, with a
    /// context, from rules written state by state, with the events leading
    /// from each state and the actions of their transitions. The types of the
    /// events, the states and the context have to be written, as they cannot
    /// be inferred from the rules.
    /// - Parameters:
    ///   - initialState: Initial state for the state machine.
    ///   - context: Initial context for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    ///   - rules: The rules defining the state machine, in event triggers.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// rules do not define a consistent state machine.
    public convenience init(initialState: State,
                            context: Context,
                            logCapacity: UInt? = nil,
                            @TransitionRuleBuilder<Event, State, Context> rules: () -> TransitionRules<Event, State, Context>) throws(StateMachine<Event, State, Context>.DefinitionError)
    {
        // Built here, so only the rules, which are values, go to the state machine.
        let built = rules()
        self.init(try StateMachine(initialState: initialState, context: context, logCapacity: logCapacity) { built })
    }

    deinit {
        // Stop following the state machine, which then forgets the stream
        // of states. The events already sent are still processed.
        following?.cancel()
        sentEvents.finish()
    }

    // MARK: - API methods

    /// Sends an event to the state machine, without waiting for it to be
    /// processed. Events are processed in the order they are sent.
    ///
    /// If the event is accepted, `state` changes a moment later. A rejected
    /// event changes nothing. Use `process(_:)` instead, to wait for the event
    /// or to know what it led to.
    ///
    /// The order is among the events sent here and with `process(_:)`. An
    /// event processed with `stateMachine` right after an event was sent can
    /// get there first.
    /// - Parameter event: Event to send.
    public func send(_ event: Event) {
        sentEvents.yield(SentEvent(event: event, waiting: nil))
    }

    /// Processes an event, after the events already sent, and waits for it.
    ///
    /// The event is in the same order as the events sent with `send(_:)`, so
    /// it is processed after them, and before events sent later. Processing
    /// it with `stateMachine` instead could get it there first.
    ///
    /// `state` changes a moment later, and has not always caught up when
    /// this returns. The event is processed also if the task waiting for it
    /// is cancelled.
    /// - Parameter event: Event to process.
    /// - Returns: The transition made, or nil if the event was rejected.
    @discardableResult
    public func process(_ event: Event) async -> TransitionEvent<Event, State>? {
        await withCheckedContinuation { continuation in
            sentEvents.yield(SentEvent(event: event, waiting: continuation))
        }
    }

    /// If the state machine accepts an event at the current state. Only the
    /// trigger of the event matters, and not what it carries.
    /// - Parameter event: Event to check.
    /// - Returns: If there is a transition for the event from the current state.
    public func accepts(_ event: Event) -> Bool {
        stateMachine.transition(from: state, for: event.eventTrigger) != nil
    }
}

// MARK: - Events sent

extension ObservableStateMachine {

    /// An event waiting to be processed, and what waits for its transition.
    struct SentEvent: Sendable {

        /// The event to process.
        let event: Event

        /// What waits for the transition the event makes, if anything does.
        let waiting: CheckedContinuation<TransitionEvent<Event, State>?, Never>?
    }
}

// MARK: - Events being their own trigger

extension ObservableStateMachine where Event.EventTrigger == Event {

    /// Creates an observable state machine with a new state machine, with a
    /// context, for events being their own trigger, which events without
    /// anything to carry are. The type of the events is then known from the
    /// transitions.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - context: Initial context for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public convenience init(transitions: Set<TransitionRule<Event, State>>,
                            initialState: State,
                            context: Context,
                            logCapacity: UInt? = nil) throws(StateMachine<Event, State, Context>.DefinitionError)
    {
        self.init(try StateMachine(transitions: transitions, initialState: initialState, context: context, logCapacity: logCapacity))
    }
}

// MARK: - Without a context

extension ObservableStateMachine where Context == Void {

    /// Creates an observable state machine with a new state machine, without
    /// a context.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public convenience init(transitions: Set<TransitionRule<Event.EventTrigger, State>>,
                            initialState: State,
                            logCapacity: UInt? = nil) throws(StateMachine<Event, State, Context>.DefinitionError)
    {
        self.init(try StateMachine(transitions: transitions, initialState: initialState, logCapacity: logCapacity))
    }

    /// Creates an observable state machine with a new state machine, without
    /// a context, from rules written state by state. The types of the events
    /// and the states have to be written, as they cannot be inferred from the rules.
    /// - Parameters:
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    ///   - rules: The rules defining the state machine, in event triggers.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// rules do not define a consistent state machine.
    public convenience init(initialState: State,
                            logCapacity: UInt? = nil,
                            @TransitionRuleBuilder<Event, State, Context> rules: () -> TransitionRules<Event, State, Context>) throws(StateMachine<Event, State, Context>.DefinitionError)
    {
        // Built here, so only the rules, which are values, go to the state machine.
        let built = rules()
        self.init(try StateMachine(initialState: initialState, logCapacity: logCapacity) { built })
    }
}

extension ObservableStateMachine where Event.EventTrigger == Event, Context == Void {

    /// Creates an observable state machine with a new state machine, without
    /// a context, for events being their own trigger. The type of the events
    /// is then known from the transitions.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public convenience init(transitions: Set<TransitionRule<Event, State>>,
                            initialState: State,
                            logCapacity: UInt? = nil) throws(StateMachine<Event, State, Context>.DefinitionError)
    {
        self.init(try StateMachine(transitions: transitions, initialState: initialState, logCapacity: logCapacity))
    }
}
