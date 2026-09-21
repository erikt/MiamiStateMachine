import MiamiStateMachine
import MiamiUI

/// The states of a door.
enum DoorState {
    case opened, closed, locked

    /// An ending state. A broken door stays broken.
    case broken
}

/// The events of a door.
enum DoorEvent {
    case open, close, lock, unlock, breakDown
}

typealias DoorTransition = StateTransition<DoorEvent, DoorState>
typealias DoorStateMachine = StateMachine<DoorEvent, DoorState>

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
typealias ObservableDoor = ObservableStateMachine<DoorEvent, DoorState>

enum DoorFixture {

    /// The definition of a state machine for a door, starting closed.
    ///
    ///     opened ◀── open ─── closed ─── lock ──▶ locked
    ///        └─── close ──▶      ◀─── unlock ───┘
    ///
    /// A door can break down when opened or closed, but not when locked.
    static let transitions: Set<DoorTransition> = [
        StateTransition(from: .closed, event: .open, to: .opened),
        StateTransition(from: .opened, event: .close, to: .closed),
        StateTransition(from: .closed, event: .lock, to: .locked),
        StateTransition(from: .locked, event: .unlock, to: .closed),
        StateTransition(from: .opened, event: .breakDown, to: .broken),
        StateTransition(from: .closed, event: .breakDown, to: .broken),
    ]
}
