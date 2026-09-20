import Foundation

/// A state machine is an actor with a current state and
/// a set of transitions defining the machine. The `StateTransition`
/// connects two states by an event.
/// 
/// The state machine actor protects the current state from outside
/// modification. The state only changes by processing events.
/// 
/// Information about the definition of the state machine can be
/// accessed by non-isolated methods.
public actor StateMachine<Event: Hashable & Sendable, State: Hashable & Sendable> {

    // MARK: - Types

    /// A stream of the transitions made by a state machine.
    public typealias TransitionStream = AsyncStream<StateTransition<Event, State>>

    /// A stream of the events rejected by a state machine, each together
    /// with the state the state machine was at when rejecting the event.
    public typealias RejectedEventStream = AsyncStream<(from: State, for: Event)>

    // MARK: - Private properties

    /// Transitions defining the state machine.
    private let transitions: Set<StateTransition<Event, State>>

    /// The transitions as a graph of states, to be able to answer questions
    /// about the state machine definition as a whole.
    private let transitionGraph: TransitionGraph<Event, State>

    /// The continuations of the transition streams in use, by stream identity.
    private var transitionContinuations: [UInt64: TransitionStream.Continuation] = [:]

    /// The continuations of the rejected event streams in use, by stream identity.
    private var rejectedEventContinuations: [UInt64: RejectedEventStream.Continuation] = [:]

    /// The identity of the next stream to be created.
    private var nextStreamID: UInt64 = 0

    // MARK: - Public isolated properties
    
    /// The current state of the state machine.
    public private(set) var state: State

    /// The starting state for the state machine.
    public let initialState: State

    /// A log keeping track of all processed transitions
    /// of the state machine. The log has a max capacity of
    /// transitions it keeps track of. When the max capacity
    /// has been reached, it throws away the oldest log
    /// entry.
    public private(set) var transitionLog: CapacityLog<StateTransition<Event, State>>

    /// Number of events processed. Includes events that
    /// did not lead to a state change for the state machine.
    public private(set) var processedEventsCount: Int = 0
    
    /// Counter for the number of state changes for this state machine.
    public private(set) var stateChangeCount: Int = 0
    
    /// The transition that led to the current state. It is nil until the
    /// first transition is made.
    ///
    /// The transition is kept apart from the transition log, so it is
    /// also known by a state machine with a log capacity of zero.
    public private(set) var enteredWith: StateTransition<Event, State>?

    // MARK: - Computed properties

    /// Number of streams created and still in use. Only for the tests of
    /// the package, to verify that streams no longer in use are forgotten.
    package var streamCount: (transitions: Int, rejectedEvents: Int) {
        return (transitionContinuations.count, rejectedEventContinuations.count)
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
    
    /// All possible events (leading to a state change) from
    /// the current state.
    public var eventsFromCurrent: Set<Event> {
        return events(from: state)
    }
    
    /// All events leading (incoming) to the current state.
    public var eventsToCurrent: Set<Event> {
        return events(to: state)
    }
    
    /// All possible outgoing transitions from the current state.
    public var transitionsFromCurrent: Set<StateTransition<Event, State>> {
        return transitions(from: state)
    }
    
    /// All possible incoming transition leading to the current state.
    public var transitionsToCurrent: Set<StateTransition<Event, State>> {
        return transitions(to: state)
    }

    // MARK: - Initialization
    
    /// Creates a new state machine.
    /// The state machine definition cannot be created if the machine
    /// is not consistent (no state where the same event leads to more
    /// than one transition to another state).
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    public init?(transitions: Set<StateTransition<Event, State>>,
                 initialState: State,
                 logCapacity: UInt? = nil)
    {
        // Check if transitions define a consistent
        // state machine. All pairs of from-state and
        // events, must be unique. Otherwise there is
        // a state where an event leads to multiple
        // different to-states.
        let fromStateAndEventPairs = transitions.map {
            (from: $0.from, event: $0.event)
        }
        
        for pair in fromStateAndEventPairs {
            // Check if each pair in the sequence is unique.
            // If it isn't there is a state with the same
            // event more than once.
            let t = fromStateAndEventPairs.filter { $0 == pair }
            if t.count > 1 {
                return nil
            }
        }
        
        self.transitions = transitions
        self.transitionGraph = TransitionGraph(transitions: transitions)
        self.transitionLog = CapacityLog(capacity: logCapacity)
        self.initialState = initialState
        self.state = initialState
    }

    deinit {
        // Finish the streams still in use. Their consumers
        // would otherwise be left waiting forever.
        for continuation in transitionContinuations.values {
            continuation.finish()
        }
        for continuation in rejectedEventContinuations.values {
            continuation.finish()
        }
    }

    // MARK: - API methods

    /// Process an event.
    ///
    /// If there is a transition from the current state for the event, the
    /// state machine will change state.
    ///
    /// - Parameters:
    ///   - event: Event to process.
    public func process(_ event: Event) {

        // Increase the counter for the number of processed events
        // by the state machine. This includes events process that
        // did not lead to a state change.
        processedEventsCount += 1

        if let t = transition(from: state, for: event) {
            commit(t)
            for continuation in transitionContinuations.values {
                continuation.yield(t)
            }
            if isAtEndingState {
                // No further transitions will be made.
                for continuation in transitionContinuations.values {
                    continuation.finish()
                }
                transitionContinuations.removeAll()
            }
        } else {
            for continuation in rejectedEventContinuations.values {
                continuation.yield((state, event))
            }
        }
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

        let id = makeStreamID()
        transitionContinuations[id] = continuation
        continuation.onTermination = { [weak self] termination in
            // A stream finished by the state machine is already removed.
            guard case .cancelled = termination else { return }
            Task { await self?.removeTransitionContinuation(id) }
        }
        return stream
    }

    /// Creates a stream of the events rejected from now on, in the order
    /// they are rejected. An event is rejected when there is no transition
    /// for the event from the current state. Every event is delivered
    /// together with the state the state machine was at.
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

        let id = makeStreamID()
        rejectedEventContinuations[id] = continuation
        continuation.onTermination = { [weak self] termination in
            // A stream is only finished by a state machine being deallocated.
            guard case .cancelled = termination else { return }
            Task { await self?.removeRejectedEventContinuation(id) }
        }
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
    public func transitionsFromCurrent(to newState: State) -> Set<StateTransition<Event, State>> {
        return transitions(from: self.state, to: newState)
    }
    
    /// All possible transitions to the current state, from another state.
    /// - Parameter oldState: From state
    /// - Returns: All possible transitions from a state to the current state.
    public func transitionsToCurrent(from oldState: State) -> Set<StateTransition<Event, State>> {
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
    public func shortestPath(to newState: State) -> [StateTransition<Event, State>]? {
        return shortestPath(from: self.state, to: newState)
    }

    // MARK: - Private methods
    
    /// Commit transition. Change the current state to the to-state
    /// in the transition and keep track of processed and accepted
    /// transitions in a stack.
    /// - Parameter transition: State machine accepted transition.
    private func commit(_ transition: StateTransition<Event, State>) {
        state = transition.to
        enteredWith = transition
        transitionLog.append(transition)
        stateChangeCount += 1
    }

    /// The identity of a new stream.
    private func makeStreamID() -> UInt64 {
        defer { nextStreamID += 1 }
        return nextStreamID
    }

    /// Forget a transition stream no longer in use, because the task
    /// of its consumer was cancelled or the stream was let go of.
    /// - Parameter id: The identity of the stream.
    private func removeTransitionContinuation(_ id: UInt64) {
        transitionContinuations[id] = nil
    }

    /// Forget a rejected event stream no longer in use, because the task
    /// of its consumer was cancelled or the stream was let go of.
    /// - Parameter id: The identity of the stream.
    private func removeRejectedEventContinuation(_ id: UInt64) {
        rejectedEventContinuations[id] = nil
    }
}

// MARK: - Non-isolated

extension StateMachine {
    
    // These are nonisolated, mostly convenience methods and
    // computed properties. All of them are only interacting
    // with constant properties not in need of state isolation
    // to be safe.
    
    /// Total number of transitions in the state machine.
    public nonisolated var numOfTransitions: Int {
        return transitions.count
    }
    
    /// The transition from a state for an event. If the state
    /// has no transition for the event, it returns nil.
    /// - Parameters:
    ///   - state: From state.
    ///   - event: Event.
    /// - Returns: Transition if there is one for the event at state.
    public nonisolated func transition(from state: State, for event: Event) -> StateTransition<Event, State>? {
        let ts = transitions.filter { t in
            return t.from == state && t.event == event
        }
        
        if ts.count > 1 {
            fatalError("Error! More than one transition defined from \(state), processing event \(event): \(ts)")
        }

        return ts.first
    }
    
    /// All transitions leading to a state for a specific event.
    /// - Parameters:
    ///   - state: To state.
    ///   - event: Event.
    /// - Returns: All transitions leading to state for an event.
    public nonisolated func transitions(to state: State, for event: Event) -> Set<StateTransition<Event, State>> {
        return transitions.filter {
            $0.to == state && $0.event == event
        }
    }
    
    /// All possible transitions from a state to another state.
    /// - Parameters:
    ///   - state: Starting state.
    ///   - newState: New state to transition to.
    /// - Returns: All possible transitions to the new state.
    public nonisolated func transitions(from state: State, to newState: State) -> Set<StateTransition<Event, State>> {
        return transitions.filter {
            $0.from == state && $0.to == newState
        }
    }
    
    /// All possible transitions from a state.
    /// - Parameter state: State to start from.
    /// - Returns: All possible transitions from state.
    public nonisolated func transitions(from state: State) -> Set<StateTransition<Event, State>> {
        return transitions.filter {
            $0.from == state
        }
    }
    
    /// All transitions leading to a state.
    /// - Parameter state: State to go to.
    /// - Returns: All possible transitions to a state.
    public nonisolated func transitions(to state: State) -> Set<StateTransition<Event, State>> {
        return transitions.filter {
            $0.to == state
        }
    }

    /// All defined and available events handled at a state.
    /// - Parameter state: State.
    /// - Returns: All events going out from this state.
    public nonisolated func events(from state: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.from == state
        }.map {
            $0.event
        })
    }
    
    /// All defined and available events leading to a state.
    /// Please note, the same event could be handled at different
    /// states, all leading to the same state.
    /// - Parameter state: State.
    /// - Returns: All events leading to this state.
    public nonisolated func events(to state: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.to == state
        }.map {
            $0.event
        })
    }
    
    /// All events defined to go from one state to another state.
    /// - Parameters:
    ///   - from: From state.
    ///   - to: To state.
    /// - Returns: All events leading from state to another state.
    public nonisolated func events(from: State, to: State) -> Set<Event> {
        return Set<Event>(transitions.filter {
            $0.from == from && $0.to == to
        }.map {
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
    /// Processing the event of each transition in the path, in order, takes
    /// a state machine that is in `state` to `newState`.
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
    public nonisolated func shortestPath(from state: State, to newState: State) -> [StateTransition<Event, State>]? {
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
        return transitions(from: state).isEmpty
    }
}
