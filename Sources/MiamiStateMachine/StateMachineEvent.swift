/// An event of a state machine. It tells what happened, and can carry
/// what it happened with, like the data loaded or the reason for a failure.
///
/// The trigger of an event is what the definition of a state machine is written
/// in: a transition leads from a state, for an event trigger, to a state. What
/// an event carries is never looked at by the state machine. It is delivered,
/// with the event, to whoever reacts to the transition made.
///
/// An event is its own trigger unless it declares another. For an event without
/// anything to carry that is what is wanted, and it needs nothing more than
/// to be declared as an event:
///
///     enum DoorEvent: StateMachineEvent {
///         case open, close
///     }
///
/// An event carrying something has to declare a trigger of its own, without what
/// is carried. If it does not, and is `Hashable`, it is its own trigger like any
/// other event. What it carries is then part of its trigger, and decides the
/// transition: a transition for `finish(bytes: 0)` is not one for
/// `finish(bytes: 512)`.
///
///     enum LoadEvent: StateMachineEvent {
///         case start
///         case finish(bytes: Int)
///         case fail(reason: String)
///
///         enum EventTrigger {
///             case start, finish, fail
///         }
///
///         var eventTrigger: EventTrigger {
///             switch self {
///             case .start: .start
///             case .finish: .finish
///             case .fail: .fail
///             }
///         }
///     }
public protocol StateMachineEvent: Sendable {

    /// What the definition of a state machine is written in. It is the
    /// event itself, unless the event declares another.
    associatedtype EventTrigger: Hashable & Sendable = Self

    /// The trigger of the event, without what the event carries.
    var eventTrigger: EventTrigger { get }
}

extension StateMachineEvent where Self: Hashable, EventTrigger == Self {

    /// The event itself, for an event that is its own trigger.
    public var eventTrigger: Self {
        return self
    }
}

/// A string is an event as it is, and its own trigger.
extension String: StateMachineEvent { }

/// An integer is an event as it is, and its own trigger.
extension Int: StateMachineEvent { }
