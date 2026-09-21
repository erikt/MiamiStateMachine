/// An event of a state machine. It tells what happened, and can carry
/// what it happened with, like the data loaded or the reason for a failure.
///
/// The kind of an event is what the definition of a state machine is written
/// in: a transition leads from a state, for a kind of event, to a state. What
/// an event carries is never looked at by the state machine. It is delivered,
/// with the event, to whoever reacts to the transition made.
///
/// An event is its own kind unless it declares another. For an event without
/// anything to carry that is what is wanted, and it needs nothing more than
/// to be declared as an event:
///
///     enum DoorEvent: StateMachineEvent {
///         case open, close
///     }
///
/// An event carrying something has to declare a kind of its own, without what
/// is carried. If it does not, and is `Hashable`, it is its own kind like any
/// other event. What it carries is then part of its kind, and decides the
/// transition: a transition for `finish(bytes: 0)` is not one for
/// `finish(bytes: 512)`.
///
///     enum LoadEvent: StateMachineEvent {
///         case start
///         case finish(bytes: Int)
///         case fail(reason: String)
///
///         enum EventKind {
///             case start, finish, fail
///         }
///
///         var eventKind: EventKind {
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
    associatedtype EventKind: Hashable & Sendable = Self

    /// The kind of the event, without what the event carries.
    var eventKind: EventKind { get }
}

extension StateMachineEvent where Self: Hashable, EventKind == Self {

    /// The event itself, for an event that is its own kind.
    public var eventKind: Self {
        return self
    }
}

/// A string is an event as it is, and its own kind.
extension String: StateMachineEvent { }

/// An integer is an event as it is, and its own kind.
extension Int: StateMachineEvent { }
