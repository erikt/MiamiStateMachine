import Foundation

/// A state machine is an actor with a current state and
/// a set of transitions defining the machine. The `StateTransition`
/// connects two states by a kind of event.
///
/// An event is a `StateMachineEvent`. It can carry something, which the
/// state machine never looks at, but delivers with the `TransitionMade`.
/// 
/// The state machine actor protects the current state from outside
/// modification. The state only changes by processing events.
/// 
/// Information about the definition of the state machine can be
/// accessed by non-isolated methods.
public actor StateMachine<Event: StateMachineEvent, State: Hashable & Sendable> {

    // MARK: - Types

    /// A stream of the transitions made by a state machine.
    public typealias TransitionStream = AsyncStream<TransitionMade<Event, State>>

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
        public let conflictingTransitions: Set<StateTransition<Event.EventKind, State>>

        public var description: String {
            // Sorted, as the same error should have the same description every time.
            let conflicts = conflictingTransitions.map { "\($0)" }.sorted().joined(separator: ", ")
            return "The transitions do not define a consistent state machine. "
                + "The same event leads from the same state to different states: \(conflicts)"
        }
    }

    // MARK: - Private properties

    /// Transitions defining the state machine.
    private let transitions: Set<StateTransition<Event.EventKind, State>>

    /// The transitions by the state they lead from and their event, to find
    /// the transition for an event without searching all transitions.
    private let transitionsByStateAndEvent: [State: [Event.EventKind: StateTransition<Event.EventKind, State>]]

    /// The transitions as a graph of states, to be able to answer questions
    /// about the state machine definition as a whole.
    private let transitionGraph: TransitionGraph<Event.EventKind, State>

    /// The kinds of streams created by the state machine.
    private enum StreamKind: Sendable {
        case transitions, rejectedEvents, states
    }

    /// The transition streams in use.
    private var transitionStreams = StreamRegistry<TransitionMade<Event, State>>()

    /// The rejected event streams in use.
    private var rejectedEventStreams = StreamRegistry<RejectedEvent<Event, State>>()

    /// The state streams in use.
    private var stateStreams = StreamRegistry<State>()

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
    public private(set) var transitionLog: CapacityLog<TransitionMade<Event, State>>

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
    public private(set) var enteredWith: TransitionMade<Event, State>?

    // MARK: - Computed properties

    /// Number of streams created and still in use. Only for the tests of
    /// the package, to verify that streams no longer in use are forgotten.
    package var streamCount: (transitions: Int, rejectedEvents: Int, states: Int) {
        return (transitionStreams.count, rejectedEventStreams.count, stateStreams.count)
    }

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
    
    /// All kinds of events accepted at the current state, which are
    /// the ones leading to a state change from it.
    public var eventsFromCurrent: Set<Event.EventKind> {
        return events(from: state)
    }
    
    /// All kinds of events leading (incoming) to the current state.
    public var eventsToCurrent: Set<Event.EventKind> {
        return events(to: state)
    }
    
    /// All possible outgoing transitions from the current state.
    public var transitionsFromCurrent: Set<StateTransition<Event.EventKind, State>> {
        return transitions(from: state)
    }
    
    /// All possible incoming transition leading to the current state.
    public var transitionsToCurrent: Set<StateTransition<Event.EventKind, State>> {
        return transitions(to: state)
    }

    /// All states that can still be reached from the current state, by
    /// processing no event, one event or several. The current state
    /// is always one of them.
    public var reachableStatesFromCurrent: Set<State> {
        return reachableStates(from: state)
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
    /// The transitions are written in kinds of events, which does not tell the
    /// type of the events, so it has to be written: `StateMachine<LoadEvent,
    /// LoadState>(transitions:initialState:)`. It is known from the transitions
    /// only for events being their own kind.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log. The entries keep the events
    ///   with what they carry, so an unlimited log is not for events carrying much.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if two
    /// or more transitions lead from the same state, for the same event,
    /// to different states.
    public init(transitions: Set<StateTransition<Event.EventKind, State>>,
                initialState: State,
                logCapacity: UInt? = nil) throws(DefinitionError)
    {
        try self.init(definedBy: transitions, initialState: initialState, logCapacity: logCapacity)
    }

    /// Creates a state machine. It is what the other initializers do, which
    /// have the same names for their parameters, and cannot call each other.
    private init(definedBy transitions: Set<StateTransition<Event.EventKind, State>>,
                 initialState: State,
                 logCapacity: UInt?) throws(DefinitionError)
    {
        // Find the transition for every state and event. A transition already
        // found for the same state and event, is a transition to another state,
        // as the transitions are a set. The state machine is then not consistent.
        var transitionsByStateAndEvent: [State: [Event.EventKind: StateTransition<Event.EventKind, State>]] = [:]
        var conflictingTransitions: Set<StateTransition<Event.EventKind, State>> = []

        for transition in transitions {
            let found = transitionsByStateAndEvent[transition.from, default: [:]]
                .updateValue(transition, forKey: transition.event)

            if let found {
                conflictingTransitions.insert(found)
                conflictingTransitions.insert(transition)
            }
        }

        guard conflictingTransitions.isEmpty else {
            throw DefinitionError(conflictingTransitions: conflictingTransitions)
        }

        self.transitions = transitions
        self.transitionsByStateAndEvent = transitionsByStateAndEvent
        self.transitionGraph = TransitionGraph(transitions: transitions)
        self.transitionLog = CapacityLog(capacity: logCapacity)
        self.initialState = initialState
        self.state = initialState
    }

    deinit {
        // Finish the streams still in use. Their consumers
        // would otherwise be left waiting forever.
        transitionStreams.finishAll()
        rejectedEventStreams.finishAll()
        stateStreams.finishAll()
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
    public func process(_ event: Event) -> TransitionMade<Event, State>? {

        // Increase the counter for the number of processed events
        // by the state machine. This includes events process that
        // did not lead to a state change.
        processedEventsCount += 1

        // The transition is found by the kind of the event. What the
        // event carries is not looked at, only delivered with the event.
        guard let t = transition(from: state, for: event.eventKind) else {
            rejectedEventStreams.yield(RejectedEvent(event: event, state: state))
            return nil
        }

        let made = TransitionMade(from: t.from, event: event, to: t.to)
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

    /// Creates a stream of the transitions made from now on, in the
    /// order they are made.
    ///
    /// Every call creates a new stream, independent of all other streams.
    /// Several consumers can each have a stream of their own, and all of
    /// them get every transition. Cancelling the task of a consumer, or
    /// letting go of a stream, ends only that stream.
    ///
    /// The stream finishes when the state machine reaches an ending state,
    /// after the transition leading there, as no further transitions will
    /// be made. A stream created at an ending state is finished from the
    /// start. The stream also finishes if the state machine is deallocated.
    ///
    /// Create the stream before processing the events of interest, and
    /// hand it over to the task consuming it. A stream created by a new
    /// task misses the transitions made before the task starts running.
    ///
    ///     let transitions = await stateMachine.transitionStream()
    ///
    ///     Task {
    ///         for await transition in transitions {
    ///             print(transition)
    ///         }
    ///     }
    ///
    /// Use the transition received, and not `state`, to know the state
    /// entered. The state machine may have moved on since the transition.
    /// - Parameter bufferingPolicy: How transitions are buffered until they
    /// are consumed. By default all of them, without any limit.
    /// - Returns: A new stream of transitions.
    public func transitionStream(
        bufferingPolicy: TransitionStream.Continuation.BufferingPolicy = .unbounded
    ) -> TransitionStream {
        let (stream, continuation) = TransitionStream.makeStream(bufferingPolicy: bufferingPolicy)

        guard !isAtEndingState else {
            continuation.finish()
            return stream
        }

        let id = transitionStreams.add(continuation)
        forgetStream(id, of: .transitions, whenCancelled: continuation)
        return stream
    }

    /// Creates a stream of the events rejected from now on, in the order
    /// they are rejected. An event is rejected when there is no transition
    /// for the event from the current state. Every event is delivered as a
    /// `RejectedEvent`, together with the state the state machine was at.
    ///
    /// Every call creates a new stream, independent of all other streams.
    /// Several consumers can each have a stream of their own, and all of
    /// them get every rejected event. Cancelling the task of a consumer, or
    /// letting go of a stream, ends only that stream.
    ///
    /// Events are rejected at an ending state as well, so the stream only
    /// finishes if the state machine is deallocated.
    ///
    /// Create the stream before processing the events of interest, and
    /// hand it over to the task consuming it, as for `transitionStream`.
    /// - Parameter bufferingPolicy: How rejected events are buffered until
    /// they are consumed. By default all of them, without any limit.
    /// - Returns: A new stream of rejected events.
    public func rejectedEventStream(
        bufferingPolicy: RejectedEventStream.Continuation.BufferingPolicy = .unbounded
    ) -> RejectedEventStream {
        let (stream, continuation) = RejectedEventStream.makeStream(bufferingPolicy: bufferingPolicy)

        let id = rejectedEventStreams.add(continuation)
        forgetStream(id, of: .rejectedEvents, whenCancelled: continuation)
        return stream
    }

    /// Creates a stream of the states the state machine is at. It starts
    /// with the current state, followed by the state entered by every
    /// transition made from now on, in the order they are made.
    ///
    /// The current state is delivered at once, so a stream tells where the
    /// state machine is whenever it is created. This makes it a good fit for
    /// a user interface. To know how a state was entered, or to not miss any
    /// transition, use `transitionStream` instead.
    ///
    /// A transition leading back to the same state delivers the state again.
    /// A rejected event delivers nothing, as the state machine stays where it is.
    ///
    /// Every call creates a new stream, independent of all other streams.
    /// Several consumers can each have a stream of their own, and all of
    /// them get every state. Cancelling the task of a consumer, or
    /// letting go of a stream, ends only that stream.
    ///
    /// The stream finishes when the state machine reaches an ending state,
    /// after delivering that state. A stream created at an ending state
    /// delivers the state and finishes. The stream also finishes if the
    /// state machine is deallocated.
    /// - Parameter bufferingPolicy: How states are buffered until they are
    /// consumed. By default all of them, without any limit. A consumer only
    /// interested in where the state machine is now, and not in the states
    /// it passed on the way, can use `.bufferingNewest(1)`.
    /// - Returns: A new stream of states, starting with the current state.
    public func stateStream(
        bufferingPolicy: StateStream.Continuation.BufferingPolicy = .unbounded
    ) -> StateStream {
        let (stream, continuation) = StateStream.makeStream(bufferingPolicy: bufferingPolicy)
        continuation.yield(state)

        guard !isAtEndingState else {
            continuation.finish()
            return stream
        }

        let id = stateStreams.add(continuation)
        forgetStream(id, of: .states, whenCancelled: continuation)
        return stream
    }

    /// If the state machine can transition to a state from the current state.
    /// - Parameter newState: State to check if it's possible to transition to.
    /// - Returns: If transition is possible.
    public func canTransition(to newState: State) -> Bool {
        return canTransition(from: self.state, to: newState)
    }
    
    /// All possible transitions from the current state, to another state.
    /// - Parameter newState: State to go to from the current state.
    /// - Returns: All possible transitions from the current state to another state.
    public func transitionsFromCurrent(to newState: State) -> Set<StateTransition<Event.EventKind, State>> {
        return transitions(from: self.state, to: newState)
    }
    
    /// All possible transitions to the current state, from another state.
    /// - Parameter oldState: From state
    /// - Returns: All possible transitions from a state to the current state.
    public func transitionsToCurrent(from oldState: State) -> Set<StateTransition<Event.EventKind, State>> {
        return transitions(from: oldState, to: self.state)
    }

    /// The shortest path from the current state to another state. This is
    /// the way to the state needing the fewest events.
    ///
    /// If there is more than one shortest path, one of them is returned.
    /// - Parameter newState: State to go to from the current state.
    /// - Returns: The transitions to make, in order, to get from the current
    /// state to the new state. If the new state cannot be reached from the
    /// current state, it returns nil. The path is empty if the new state is
    /// the current state.
    public func shortestPath(to newState: State) -> [StateTransition<Event.EventKind, State>]? {
        return shortestPath(from: self.state, to: newState)
    }

    // MARK: - Private methods
    
    /// Commit transition. Change the current state to the to-state
    /// in the transition and keep track of processed and accepted
    /// transitions in a stack.
    /// - Parameter transition: State machine accepted transition.
    private func commit(_ transition: TransitionMade<Event, State>) {
        state = transition.to
        enteredWith = transition
        transitionLog.append(transition)
        stateChangeCount += 1
    }

    /// Forget a stream when it is no longer in use, because the task of its
    /// consumer was cancelled or the stream was let go of. A stream finished
    /// by the state machine itself is already forgotten.
    /// - Parameters:
    ///   - id: The identity of the stream.
    ///   - kind: The kind of stream.
    ///   - continuation: The continuation feeding the stream.
    private func forgetStream<Element>(_ id: UInt64,
                                       of kind: StreamKind,
                                       whenCancelled continuation: AsyncStream<Element>.Continuation)
    {
        continuation.onTermination = { [weak self] termination in
            guard case .cancelled = termination else { return }

            // Called from anywhere, so a task is needed to get to the state machine.
            Task { await self?.forgetStream(id, of: kind) }
        }
    }

    /// Forget a stream no longer in use.
    /// - Parameters:
    ///   - id: The identity of the stream.
    ///   - kind: The kind of stream.
    private func forgetStream(_ id: UInt64, of kind: StreamKind) {
        switch kind {
        case .transitions:
            transitionStreams.remove(id)
        case .rejectedEvents:
            rejectedEventStreams.remove(id)
        case .states:
            stateStreams.remove(id)
        }
    }
}

// MARK: - Events being their own kind

extension StateMachine where Event.EventKind == Event {

    /// Creates a state machine for events being their own kind, which
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
    public init(transitions: Set<StateTransition<Event, State>>,
                initialState: State,
                logCapacity: UInt? = nil) throws(DefinitionError)
    {
        try self.init(definedBy: transitions, initialState: initialState, logCapacity: logCapacity)
    }
}

// MARK: - Definition error

extension StateMachine.DefinitionError: LocalizedError {
    public var errorDescription: String? {
        return description
    }
}

// MARK: - Non-isolated

extension StateMachine {
    
    // These are nonisolated, mostly convenience methods and
    // computed properties. All of them are only interacting
    // with constant properties not in need of state isolation
    // to be safe.
    
    /// Total number of transitions defining the state machine. The number of
    /// transitions made by the state machine is `stateChangeCount`.
    public nonisolated var transitionCount: Int {
        return transitions.count
    }
    
    /// The transition from a state for a kind of event. If the state
    /// has no transition for it, it returns nil. For an event, ask
    /// with `event.eventKind`.
    /// - Parameters:
    ///   - state: From state.
    ///   - event: Event.
    /// - Returns: Transition if there is one for the event at state.
    public nonisolated func transition(from state: State, for event: Event.EventKind) -> StateTransition<Event.EventKind, State>? {
        return transitionsByStateAndEvent[state]?[event]
    }
    
    /// All transitions leading to a state for a specific kind of event.
    /// - Parameters:
    ///   - state: To state.
    ///   - event: Event.
    /// - Returns: All transitions leading to state for an event.
    public nonisolated func transitions(to state: State, for event: Event.EventKind) -> Set<StateTransition<Event.EventKind, State>> {
        return transitions.filter {
            $0.to == state && $0.event == event
        }
    }
    
    /// All possible transitions from a state to another state.
    /// - Parameters:
    ///   - state: Starting state.
    ///   - newState: New state to transition to.
    /// - Returns: All possible transitions to the new state.
    public nonisolated func transitions(from state: State, to newState: State) -> Set<StateTransition<Event.EventKind, State>> {
        return transitions(from: state).filter {
            $0.to == newState
        }
    }
    
    /// All possible transitions from a state.
    /// - Parameter state: State to start from.
    /// - Returns: All possible transitions from state.
    public nonisolated func transitions(from state: State) -> Set<StateTransition<Event.EventKind, State>> {
        guard let transitionsByEvent = transitionsByStateAndEvent[state] else {
            return []
        }
        return Set(transitionsByEvent.values)
    }
    
    /// All transitions leading to a state.
    /// - Parameter state: State to go to.
    /// - Returns: All possible transitions to a state.
    public nonisolated func transitions(to state: State) -> Set<StateTransition<Event.EventKind, State>> {
        return transitions.filter {
            $0.to == state
        }
    }

    /// All kinds of events handled at a state.
    /// - Parameter state: State.
    /// - Returns: All kinds of events going out from this state.
    public nonisolated func events(from state: State) -> Set<Event.EventKind> {
        guard let transitionsByEvent = transitionsByStateAndEvent[state] else {
            return []
        }
        return Set(transitionsByEvent.keys)
    }
    
    /// All kinds of events leading to a state.
    /// Please note, the same kind of event could be handled at different
    /// states, all leading to the same state.
    /// - Parameter state: State.
    /// - Returns: All events leading to this state.
    public nonisolated func events(to state: State) -> Set<Event.EventKind> {
        return Set<Event.EventKind>(transitions.filter {
            $0.to == state
        }.map {
            $0.event
        })
    }
    
    /// All kinds of events defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    public nonisolated func events(from: State, to: State) -> Set<Event.EventKind> {
        return Set<Event.EventKind>(transitions(from: from, to: to).map {
            $0.event
        })
    }
    
    /// If it is possible to transition from a state to another state.
    /// - Parameters:
    ///   - state: State to transition from.
    ///   - newState: State to transition to.
    /// - Returns: If transition is possible.
    public nonisolated func canTransition(from state: State, to newState: State) -> Bool {
        return !transitions(from: state, to: newState).isEmpty
    }

    /// The shortest path from a state to another state. This is the way
    /// between the states needing the fewest events.
    ///
    /// Processing an event of the kind of each transition in the path, in
    /// order, takes a state machine that is in `state` to `newState`. An
    /// event without anything to carry is its own kind, and can be processed
    /// as it is in the path.
    ///
    /// If there is more than one shortest path, one of them is returned.
    /// Which one is unspecified, but repeated calls on the same state
    /// machine instance return the same path.
    /// - Parameters:
    ///   - state: State to start from.
    ///   - newState: State to go to.
    /// - Returns: The transitions to make, in order, to get from the state to
    /// the new state. If the new state cannot be reached from the state,
    /// it returns nil. The path is empty if the two states are the same.
    public nonisolated func shortestPath(from state: State, to newState: State) -> [StateTransition<Event.EventKind, State>]? {
        return transitionGraph.shortestPath(from: state, to: newState)
    }
    
    /// If a state is an ending state. No transitions lead from an ending
    /// state, so a state machine at the state will not accept any events.
    ///
    /// A state with a transition leading back to the same state
    /// is not an ending state.
    /// - Parameter state: State to check if it's an ending state.
    /// - Returns: If the state is an ending state.
    public nonisolated func isEndingState(_ state: State) -> Bool {
        return transitionsByStateAndEvent[state] == nil
    }
}

// MARK: - Checks of the definition

extension StateMachine {

    // These are about the definition of the state machine as a whole, and
    // are useful for finding mistakes in it. Like the other nonisolated
    // members, they only use constant properties.

    /// All states of the state machine. These are the initial state,
    /// and every state a transition leads from or to.
    public nonisolated var states: Set<State> {
        return transitionGraph.states.union([initialState])
    }

    /// All ending states of the state machine. No transitions lead from an
    /// ending state, so a state machine at the state will not accept any events.
    public nonisolated var endingStates: Set<State> {
        return states.filter { isEndingState($0) }
    }

    /// All states that can be reached from a state, by processing no
    /// event, one event or several. The state itself is always one of
    /// them, as it is reached without processing any event.
    ///
    /// A state is reachable from another state exactly when there is
    /// a shortest path between them.
    /// - Parameter state: State to start from.
    /// - Returns: The state, and every state that can be reached from it.
    public nonisolated func reachableStates(from state: State) -> Set<State> {
        return transitionGraph.reachableStates(from: state)
    }

    /// All states that cannot be reached from the initial state. The state
    /// machine will never be at any of them.
    ///
    /// An unreachable state is often a mistake in the definition, like a
    /// missing transition, or a transition leading to the wrong state.
    public nonisolated var unreachableStates: Set<State> {
        return states.subtracting(reachableStates(from: initialState))
    }

    /// All states without a path to any ending state. A state machine
    /// getting to one of them will never reach an ending state.
    ///
    /// For a state machine meant to end, such a state is a mistake in the
    /// definition. For a state machine without ending states, meant to go
    /// on forever, these are all its states.
    public nonisolated var statesWithoutPathToEndingState: Set<State> {
        return states.subtracting(transitionGraph.states(leadingToAnyOf: endingStates))
    }

    /// If the definition has a cycle. A cycle is a way from a state back to
    /// the same state, by one transition or several. A state machine with
    /// a cycle can go on processing events forever.
    ///
    /// A cycle among unreachable states counts as well, as this
    /// is about the definition and not about the initial state.
    public nonisolated var hasCycle: Bool {
        return transitionGraph.hasCycle
    }
}
