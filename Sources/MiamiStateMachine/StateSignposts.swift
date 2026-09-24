#if canImport(os)
import os
#endif

/// The signposts of a state machine, which show what it does in Instruments.
///
/// Every state is an interval, from the transition entering it to the
/// transition leaving it, ended with the trigger of the event leaving it.
/// Every event rejected is a signpost event. Each state machine has a
/// signpost ID of its own, so it is a lane of its own.
///
/// The signposts are for dynamic tracing, in the subsystem `MiamiStateMachine`.
/// They are only written while Instruments records with the subsystem among
/// the subsystems for dynamic tracing of the os_signpost instrument. Otherwise
/// nothing is written, and no text is made, so they cost next to nothing.
/// A state entered before the recording started is not shown, so the lane of
/// a state machine starts with its first transition during the recording.
///
/// States are written with the name of their type, and events by their
/// trigger, never with what they carry. Both are written as public text.
///
/// Where the module `os` is missing, like on Linux, nothing is written.
struct StateSignposts<State> {

    #if canImport(os)

    /// Writes the signposts.
    private let signposter = OSSignposter(subsystem: "MiamiStateMachine", category: .dynamicTracing)

    /// The signpost ID of the state machine.
    private let id: OSSignpostID

    /// The interval of the current state, until the state is left.
    private var currentState: OSSignpostIntervalState?

    #endif

    /// Creates the signposts of a state machine.
    init() {
        #if canImport(os)
        id = signposter.makeSignpostID()
        #endif
    }

    /// Begins the interval of a state, entered at the start or by a transition.
    /// - Parameter state: The state entered.
    mutating func enter(_ state: State) {
        #if canImport(os)
        // Beginning an interval makes an object, also when nothing records.
        guard signposter.isEnabled else {
            currentState = nil
            return
        }
        currentState = signposter.beginInterval(
            "State", id: id,
            "\(String(describing: State.self), privacy: .public).\(String(describing: state), privacy: .public)")
        #endif
    }

    /// Ends the interval of the current state, left by a transition.
    /// - Parameter trigger: The trigger of the event leaving the state.
    mutating func leave<Trigger>(by trigger: Trigger) {
        #if canImport(os)
        if let currentState {
            signposter.endInterval("State", currentState, "Left by \(String(describing: trigger), privacy: .public)")
        }
        currentState = nil
        #endif
    }

    /// Ends the interval of the current state, as the state machine is deallocated.
    mutating func end() {
        #if canImport(os)
        if let currentState {
            signposter.endInterval("State", currentState)
        }
        currentState = nil
        #endif
    }

    /// Writes an event rejected, as there is no transition for it.
    /// - Parameters:
    ///   - trigger: The trigger of the event.
    ///   - state: The state the event was rejected at.
    func reject<Trigger>(_ trigger: Trigger, at state: State) {
        #if canImport(os)
        signposter.emitEvent(
            "Rejected Event", id: id,
            "\(String(describing: trigger), privacy: .public) at \(String(describing: State.self), privacy: .public).\(String(describing: state), privacy: .public)")
        #endif
    }
}
