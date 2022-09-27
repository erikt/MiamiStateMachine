import Foundation

/// Any possible side-effects when doing a transition between
/// states, is handled by the delegate method, called after the actual
/// state change. The same goes for when an event does not trigger
/// a state change.
///
/// Please note, there is not a delegate method called *before* the
/// state change (when an event leads to a state change). This is
/// by design to protect from the difficult situation where the
/// side-effect delegate method itself changes the state. The state
/// machine would then most likely be in an undefined, illegal state.
public protocol StateMachineDelegate: AnyObject {
    /// The state machine has processed an event and transitioned
    /// and changed to another state.
    /// - Parameter transition: Transition that changed state.
    func didChangeState<Event: Hashable & Sendable, State: Hashable & Sendable>(with transition: Transition<Event, State>)
    
    /// The state machine has processed an event, but there was no
    /// defined transition from the current state for this event.
    /// There was no change of state.
    /// - Parameter event: Event that did not change state.
    func didNotChangeState<Event: Hashable & Sendable, State: Hashable & Sendable>(from state: State, for event: Event)
}
