// MARK: - Waiting

extension StateMachine {

    /// Waits until the state machine is at a state.
    ///
    /// It returns at once if the state machine is already at the state.
    /// Otherwise it waits for a transition leading to the state. A state
    /// entered and left again before the waiting task runs still counts,
    /// so read `state` to know where the state machine is by then.
    ///
    /// The waiting ends without the state being reached when the state
    /// machine gets to a state from which the state can no longer be reached,
    /// like an ending state, and when the task waiting is cancelled.
    ///
    /// Like a stream, it only knows the transitions made after it was
    /// called. A state entered and left again before the call is missed,
    /// which can happen when it is called from a new task, as the task can
    /// start running after the events were processed. A state the state
    /// machine stays at, like an ending state, is never missed.
    ///
    ///     Task {
    ///         if await stateMachine.wait(for: .delivered) {
    ///             print("Delivered")
    ///         }
    ///     }
    ///
    /// A task waiting keeps the state machine. For a state machine without
    /// ending states, cancel the task when the state is no longer of interest.
    /// - Parameter awaitedState: The state to wait for.
    /// - Returns: If the state machine got to the state. It is false if the
    /// state machine can no longer get there, or the task was cancelled.
    @discardableResult
    public func wait(for awaitedState: State) async -> Bool {
        guard state != awaitedState else {
            return true
        }

        // The states from which the awaited state can still be reached,
        // found by one search backwards instead of one for every state.
        let leadingToAwaitedState = definition.graph.states(leadingToAnyOf: [awaitedState])

        for await entered in stateStream() {
            if entered == awaitedState {
                return true
            }
            guard leadingToAwaitedState.contains(entered) else {
                return false
            }
        }

        // The task was cancelled.
        return false
    }

    /// Process an event after some time, if the state machine is still at a
    /// state by then, like a timeout of a state.
    ///
    /// It waits for the time, and then processes the event, if the state
    /// machine has stayed at the state all the time. A transition in between
    /// ends the waiting at once, and the event is not processed at all. A
    /// transition leading back to the same state counts as leaving it, so an
    /// event of activity at a state, like a coin inserted, starts it over,
    /// when the timeout is asked for again.
    ///
    ///     // Give up connecting after ten seconds.
    ///     Task {
    ///         try await connection.process(.timeout, after: .seconds(10), ifStillAt: .connecting)
    ///     }
    ///
    /// The event is processed like any other event when the time has passed,
    /// and can be rejected like any other event.
    ///
    /// Cancelling the task waiting cancels the timeout, and nothing is processed.
    /// - Parameters:
    ///   - event: Event to process.
    ///   - delay: How long the state machine has to stay at the state.
    ///   - state: The state the state machine has to be at now, and stay at.
    ///   - clock: The clock measuring the time. By default the continuous clock.
    /// - Returns: The transition made. It is nil if the state machine was not
    /// at the state, left it before the time had passed, or rejected the event.
    /// - Throws: `CancellationError` if the task is cancelled while waiting.
    @discardableResult
    public func process<C: Clock>(_ event: Event,
                                  after delay: C.Duration,
                                  ifStillAt state: State,
                                  clock: C = ContinuousClock()) async throws(CancellationError) -> TransitionEvent<Event, State>?
    {
        guard self.state == state else {
            return nil
        }

        // Every transition, also one back to the same state, is counted.
        let changesAtStart = stateChangeCount

        // Whichever comes first: the time passing, or a transition. The stream
        // keeps every state: keeping only the newest could drop the current
        // state before it is read, and the transition would be taken for it.
        let states = stateStream()
        let timeHasPassed: Bool
        do {
            timeHasPassed = try await withThrowingTaskGroup(of: Bool?.self) { group in
                group.addTask {
                    try await clock.sleep(for: delay)
                    return true
                }
                group.addTask {
                    // The first state is the current one. Another one is a transition.
                    var entered = states.makeAsyncIterator()
                    _ = await entered.next()
                    return await entered.next() == nil ? nil : false
                }
                defer { group.cancelAll() }

                // A stream finished by an ending state tells nothing, so wait for the other.
                while let result = try await group.next() {
                    if let result {
                        return result
                    }
                }
                return false
            }
        } catch {
            throw CancellationError()
        }

        // Checked and processed without any suspension, so nothing comes in between.
        guard timeHasPassed, stateChangeCount == changesAtStart else {
            return nil
        }
        return process(event)
    }
}
