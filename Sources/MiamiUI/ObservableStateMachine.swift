import MiamiStateMachine
import Observation

/// A state machine for a user interface. It has the current state of a
/// `StateMachine` as an observable property on the main actor, so a SwiftUI
/// view using `state` is updated when the state machine makes a transition.
///
///     struct DoorView: View {
///         @State private var door: ObservableStateMachine<DoorEvent, DoorState>
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
/// moved on. Use the state machine itself, by `stateMachine`, to know what
/// an event led to, or for anything else the observable state machine lacks.
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
@MainActor
@Observable
public final class ObservableStateMachine<Event: StateMachineEvent, State: Hashable & Sendable> {

    // MARK: - Public properties

    /// The state machine being observed.
    public let stateMachine: StateMachine<Event, State>

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
    private let sentEvents: AsyncStream<Event>.Continuation

    /// The task following the states of the state machine.
    @ObservationIgnored
    private var following: Task<Void, Never>?

    // MARK: - Computed properties

    /// All event symbols the state machine accepts at the current state.
    public var eventsFromCurrent: Set<Event.EventSymbol> {
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
    public init(_ stateMachine: StateMachine<Event, State>) {
        self.stateMachine = stateMachine
        self.state = stateMachine.initialState

        // A task for every event could get the events to the state machine in
        // another order than they were sent. One task taking them from a
        // stream keeps the order. It ends when the stream is finished.
        let (events, sentEvents) = AsyncStream.makeStream(of: Event.self)
        self.sentEvents = sentEvents
        Task {
            for await event in events {
                await stateMachine.process(event)
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

    /// Creates an observable state machine with a new state machine.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public convenience init(transitions: Set<StateTransition<Event.EventSymbol, State>>,
                            initialState: State,
                            logCapacity: UInt? = nil) throws(StateMachine<Event, State>.DefinitionError)
    {
        self.init(try StateMachine(transitions: transitions, initialState: initialState, logCapacity: logCapacity))
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
    /// event changes nothing. Process the event with `stateMachine` instead,
    /// to wait for it or to know what it led to.
    ///
    /// The order is among the events sent here. An event processed with
    /// `stateMachine` right after an event was sent can get there first.
    /// - Parameter event: Event to send.
    public func send(_ event: Event) {
        sentEvents.yield(event)
    }

    /// If the state machine accepts an event at the current state. Only the
    /// symbol of the event matters, and not what it carries.
    /// - Parameter event: Event to check.
    /// - Returns: If there is a transition for the event from the current state.
    public func accepts(_ event: Event) -> Bool {
        stateMachine.transition(from: state, for: event.eventSymbol) != nil
    }
}

// MARK: - Events being their own symbol

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
extension ObservableStateMachine where Event.EventSymbol == Event {

    /// Creates an observable state machine with a new state machine, for
    /// events being their own symbol, which events without anything to carry
    /// are. The type of the events is then known from the transitions.
    /// - Parameters:
    ///   - transitions: Transitions defining the state machine.
    ///   - initialState: Initial state for the state machine.
    ///   - logCapacity: Max capacity of transition log. Set to nil for unlimited
    ///   number of entries in the transition log.
    /// - Throws: A `DefinitionError` with the transitions in conflict, if the
    /// transitions do not define a consistent state machine.
    public convenience init(transitions: Set<StateTransition<Event, State>>,
                            initialState: State,
                            logCapacity: UInt? = nil) throws(StateMachine<Event, State>.DefinitionError)
    {
        self.init(try StateMachine(transitions: transitions, initialState: initialState, logCapacity: logCapacity))
    }
}
