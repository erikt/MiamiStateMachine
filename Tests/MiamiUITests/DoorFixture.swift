import MiamiStateMachine
import MiamiUI

/// The states of a door.
enum DoorState {
    case opened, closed, locked

    /// An ending state. A broken door stays broken.
    case broken
}

/// The events of a door.
enum DoorEvent: StateMachineEvent {
    case open, close, lock, unlock, breakDown
}

typealias DoorTransition = TransitionRule<DoorEvent, DoorState>
typealias DoorStateMachine = StateMachine<DoorEvent, DoorState>

typealias ObservableDoor = ObservableStateMachine<DoorEvent, DoorState>

enum DoorFixture {

    /// The definition of a state machine for a door, starting closed.
    ///
    ///     opened ◀── open ─── closed ─── lock ──▶ locked
    ///        └─── close ──▶      ◀─── unlock ───┘
    ///
    /// A door can break down when opened or closed, but not when locked.
    static let transitions: Set<DoorTransition> = [
        TransitionRule(from: .closed, event: .open, to: .opened),
        TransitionRule(from: .opened, event: .close, to: .closed),
        TransitionRule(from: .closed, event: .lock, to: .locked),
        TransitionRule(from: .locked, event: .unlock, to: .closed),
        TransitionRule(from: .opened, event: .breakDown, to: .broken),
        TransitionRule(from: .closed, event: .breakDown, to: .broken),
    ]
}
