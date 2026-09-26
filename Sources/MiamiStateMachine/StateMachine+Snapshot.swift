// MARK: - Snapshots

extension StateMachine {

    /// What a state machine is at, apart from its definition: its state, its
    /// context, its transition log and its counts, with the rules it was made
    /// with. A state machine can be restored from it, with its rules given
    /// again, as a snapshot never holds the actions, which are code.
    ///
    ///     let data = try JSONEncoder().encode(await stateMachine.snapshot)
    ///
    /// A snapshot is read from a state machine in one go, so its parts always
    /// agree, and it is only made by a state machine or by decoding one.
    ///
    /// When the state was entered is not in it, as an instant only means
    /// something in the process it was read in.
    ///
    /// A snapshot can be encoded when its events, states and event triggers
    /// can, and decoded when they can be decoded. The keys are the names of
    /// its properties: `state`, `context`, `transitionLog`, `processedEventsCount`,
    /// `stateChangeCount`, `enteredWith`, left out before the first
    /// transition, and `rules`. The context is left out when it is `Void`, and
    /// any other context has to be `Codable` too. That is checked when coding,
    /// as `Void` cannot be `Codable`, and it is an error otherwise.
    ///
    /// Decoding checks that the snapshot agrees with itself, as one made by
    /// a state machine does: that its counts add up, and that its transitions
    /// were made with its rules, the last of them leading to its state.
    public struct Snapshot: Sendable {

        /// The state the state machine was at.
        public let state: State

        /// The context the state machine had.
        public let context: Context

        /// The transition log, with its max capacity.
        public let transitionLog: CapacityLog<TransitionEvent<Event, State>>

        /// Number of events processed, accepted or rejected.
        public let processedEventsCount: Int

        /// Number of transitions made.
        public let stateChangeCount: Int

        /// The transition that led to the state. It is nil if no
        /// transition had been made.
        public let enteredWith: TransitionEvent<Event, State>?

        /// The rules the state machine was defined by. A snapshot can only
        /// be restored with rules including all of them.
        public let rules: Set<TransitionRule<Event.EventTrigger, State>>
    }

    /// A snapshot of the state machine as it is now, to save it and restore
    /// it later, with `init(transitions:initialState:restoring:logCapacity:)`
    /// or `init(initialState:restoring:logCapacity:rules:)`.
    public var snapshot: Snapshot {
        return Snapshot(state: state,
                        context: context,
                        transitionLog: transitionLog,
                        processedEventsCount: processedEventsCount,
                        stateChangeCount: stateChangeCount,
                        enteredWith: enteredWith,
                        rules: definition.rules)
    }
}

// MARK: - Coding snapshots

extension StateMachine.Snapshot {

    /// The keys of a saved snapshot, the names of its properties.
    enum CodingKeys: String, CodingKey {
        case state, context, transitionLog, processedEventsCount, stateChangeCount, enteredWith, rules
    }
}

extension StateMachine.Snapshot: Encodable where Event: Encodable, State: Encodable, Event.EventTrigger: Encodable {

    /// Encodes the snapshot. The context is left out when it is `Void`.
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: An `EncodingError` if the context is not `Encodable`, or
    /// any error of the encoder.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)

        // Encodable cannot be required of the context, as Void cannot conform
        // to it, so it is checked here. A Void context has nothing to save.
        if Context.self != Void.self {
            guard let context = context as? any Encodable else {
                throw EncodingError.invalidValue(context, EncodingError.Context(
                    codingPath: encoder.codingPath + [CodingKeys.context],
                    debugDescription: "The context, of type \(Context.self), is not Encodable."))
            }
            try container.encode(context, forKey: .context)
        }

        try container.encode(transitionLog, forKey: .transitionLog)
        try container.encode(processedEventsCount, forKey: .processedEventsCount)
        try container.encode(stateChangeCount, forKey: .stateChangeCount)
        try container.encodeIfPresent(enteredWith, forKey: .enteredWith)
        try container.encode(rules, forKey: .rules)
    }
}

extension StateMachine.Snapshot: Decodable where Event: Decodable, State: Decodable, Event.EventTrigger: Decodable {

    /// Decodes a snapshot, and checks that it agrees with itself.
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A `DecodingError` if the context is not `Decodable`, if the
    /// snapshot does not agree with itself, or any error of the decoder.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(State.self, forKey: .state)

        // Decodable cannot be required of the context, as Void cannot conform
        // to it, so it is checked here. A Void context was not saved.
        let context: Context
        if Context.self == Void.self {
            context = () as! Context
        } else if let type = Context.self as? any Decodable.Type {
            context = try container.decode(type, forKey: .context) as! Context
        } else {
            throw DecodingError.typeMismatch(Context.self, DecodingError.Context(
                codingPath: decoder.codingPath + [CodingKeys.context],
                debugDescription: "The context, of type \(Context.self), is not Decodable."))
        }

        let transitionLog = try container.decode(CapacityLog<TransitionEvent<Event, State>>.self, forKey: .transitionLog)
        let processedEventsCount = try container.decode(Int.self, forKey: .processedEventsCount)
        let stateChangeCount = try container.decode(Int.self, forKey: .stateChangeCount)
        let enteredWith = try container.decodeIfPresent(TransitionEvent<Event, State>.self, forKey: .enteredWith)
        let rules = try container.decode(Set<TransitionRule<Event.EventTrigger, State>>.self, forKey: .rules)

        // A snapshot made by a state machine agrees with itself. One that does
        // not was changed, and restoring it would break what the state machine
        // promises, like its counts adding up.
        func disagreement(_ description: String) -> DecodingError {
            DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: description))
        }
        guard 0 <= stateChangeCount, stateChangeCount <= processedEventsCount else {
            throw disagreement("The counts do not add up: \(stateChangeCount) transitions made of \(processedEventsCount) events processed.")
        }
        guard (enteredWith == nil) == (stateChangeCount == 0) else {
            throw disagreement("The transition entering the state is saved exactly when a transition has been made.")
        }
        guard transitionLog.count <= stateChangeCount else {
            throw disagreement("The transition log has more transitions than were made.")
        }
        guard enteredWith.map({ $0.to == state }) ?? true, transitionLog.last.map({ $0.to == state }) ?? true else {
            throw disagreement("The last transition does not lead to the state.")
        }
        guard enteredWith.map({ rules.contains($0.rule) }) ?? true, transitionLog.allSatisfy({ rules.contains($0.rule) }) else {
            throw disagreement("A transition was made with a rule that is not among the rules.")
        }

        self.init(state: state,
                  context: context,
                  transitionLog: transitionLog,
                  processedEventsCount: processedEventsCount,
                  stateChangeCount: stateChangeCount,
                  enteredWith: enteredWith,
                  rules: rules)
    }
}
