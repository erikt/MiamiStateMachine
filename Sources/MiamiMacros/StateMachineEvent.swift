import MiamiStateMachine

/// Makes an enumeration of events a `StateMachineEvent`, and writes its
/// triggers: the events without what they carry.
///
/// The macro adds the conformance to `StateMachineEvent`, an enumeration
/// `EventTrigger` with a case for every case of the events, and the property
/// `eventTrigger`, mapping every event to its trigger:
///
///     @StateMachineEvent
///     enum LoadEvent {
///         case start
///         case finish(bytes: Int)
///         case fail(reason: String)
///     }
///
///     let transitions: Set<TransitionRule<LoadEvent.EventTrigger, LoadState>> = [
///         TransitionRule(from: .loading, event: .finish, to: .ready),
///     ]
///
/// The triggers are `Hashable`, `Sendable`, `CaseIterable` and `Codable`, and
/// have the access level of the events. The events have to be `Sendable`,
/// which they are when what they carry is.
///
/// An enumeration of events without anything to carry does not need the
/// macro. It is its own trigger, and only has to declare the conformance.
@attached(member, names: named(EventTrigger), named(eventTrigger))
@attached(extension, conformances: MiamiStateMachine.StateMachineEvent)
public macro StateMachineEvent() = #externalMacro(module: "MiamiMacrosPlugin", type: "StateMachineEventMacro")
