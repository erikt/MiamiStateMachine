// MARK: - Streams

extension StateMachine {

    /// The kinds of streams created by the state machine.
    enum StreamKind: Sendable {
        case transitions, rejectedEvents, states
    }

    /// Number of streams created and still in use. Only for the tests of
    /// the package, to verify that streams no longer in use are forgotten.
    package var streamCount: (transitions: Int, rejectedEvents: Int, states: Int) {
        return (transitionStreams.count, rejectedEventStreams.count, stateStreams.count)
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

        let id = transitionStreams.add(continuation)
        forgetStream(id, of: .transitions, whenCancelled: continuation)
        return stream
    }

    /// Creates a stream of the events rejected from now on, in the order
    /// they are rejected. An event is rejected when there is no transition
    /// for the event from the current state. Every event is delivered as a
    /// `RejectedEvent`, together with the state the state machine was at.
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

        let id = rejectedEventStreams.add(continuation)
        forgetStream(id, of: .rejectedEvents, whenCancelled: continuation)
        return stream
    }

    /// Creates a stream of the states the state machine is at. It starts
    /// with the current state, followed by the state entered by every
    /// transition made from now on, in the order they are made.
    ///
    /// The current state is delivered at once, so a stream tells where the
    /// state machine is whenever it is created. This makes it a good fit for
    /// a user interface. To know how a state was entered, or to not miss any
    /// transition, use `transitionStream` instead.
    ///
    /// A transition leading back to the same state delivers the state again.
    /// A rejected event delivers nothing, as the state machine stays where it is.
    ///
    /// Every call creates a new stream, independent of all other streams.
    /// Several consumers can each have a stream of their own, and all of
    /// them get every state. Cancelling the task of a consumer, or
    /// letting go of a stream, ends only that stream.
    ///
    /// The stream finishes when the state machine reaches an ending state,
    /// after delivering that state. A stream created at an ending state
    /// delivers the state and finishes. The stream also finishes if the
    /// state machine is deallocated.
    /// - Parameter bufferingPolicy: How states are buffered until they are
    /// consumed. By default all of them, without any limit. A consumer only
    /// interested in where the state machine is now, and not in the states
    /// it passed on the way, can use `.bufferingNewest(1)`.
    /// - Returns: A new stream of states, starting with the current state.
    public func stateStream(
        bufferingPolicy: StateStream.Continuation.BufferingPolicy = .unbounded
    ) -> StateStream {
        let (stream, continuation) = StateStream.makeStream(bufferingPolicy: bufferingPolicy)
        continuation.yield(state)

        guard !isAtEndingState else {
            continuation.finish()
            return stream
        }

        let id = stateStreams.add(continuation)
        forgetStream(id, of: .states, whenCancelled: continuation)
        return stream
    }

    /// Forget a stream when it is no longer in use, because the task of its
    /// consumer was cancelled or the stream was let go of. A stream finished
    /// by the state machine itself is already forgotten.
    /// - Parameters:
    ///   - id: The identity of the stream.
    ///   - kind: The kind of stream.
    ///   - continuation: The continuation feeding the stream.
    private func forgetStream<Element>(_ id: UInt64,
                                       of kind: StreamKind,
                                       whenCancelled continuation: AsyncStream<Element>.Continuation)
    {
        continuation.onTermination = { [weak self] termination in
            guard case .cancelled = termination else { return }

            // Called from anywhere, so a task is needed to get to the state machine.
            Task { await self?.forgetStream(id, of: kind) }
        }
    }

    /// Forget a stream no longer in use.
    /// - Parameters:
    ///   - id: The identity of the stream.
    ///   - kind: The kind of stream.
    private func forgetStream(_ id: UInt64, of kind: StreamKind) {
        switch kind {
        case .transitions:
            transitionStreams.remove(id)
        case .rejectedEvents:
            rejectedEventStreams.remove(id)
        case .states:
            stateStreams.remove(id)
        }
    }
}
