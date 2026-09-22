import Foundation
import Testing
import MiamiStateMachine

/// Transitions and rejected events are saved with the names of their
/// properties as keys, and a log with keys of its own. The keys are what
/// saved data depends on, so the tests spell out the saved format, and do
/// not only encode and decode.
struct CodableTests {

    // MARK: - Fixture

    /// The states of a traffic light, saved by their names.
    enum LightState: String, Codable {
        case red, amber, green

        /// An ending state. The light stays dark.
        case dark
    }

    /// The events of a traffic light, saved by their names.
    enum LightEvent: String, Codable, StateMachineEvent {
        case next, fail
    }

    typealias LightTransition = StateTransition<LightEvent, LightState>
    typealias LightRejectedEvent = RejectedEvent<LightEvent, LightState>

    /// An enumeration without a raw type, saved the way Swift chooses.
    enum Switch: Codable {
        case on, off
    }

    /// Can be saved, but not read.
    struct OnlyEncodable: Hashable, Encodable, StateMachineEvent {
        let name: String
    }

    /// Can be read, but not saved.
    struct OnlyDecodable: Hashable, Decodable, StateMachineEvent {
        let name: String
    }

    /// A value encoded as JSON, with the keys sorted to be the same every time.
    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    /// A value decoded from JSON.
    private func decoded<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    /// A value encoded and decoded again, as JSON and as a property list.
    private func expectUnchangedWhenSaved<Value: Codable & Equatable>(_ value: Value) throws {
        let json = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(Value.self, from: json) == value)

        let propertyList = try PropertyListEncoder().encode(value)
        #expect(try PropertyListDecoder().decode(Value.self, from: propertyList) == value)
    }

    // MARK: - Transitions

    @Test func transitionIsUnchangedWhenSaved() throws {
        try expectUnchangedWhenSaved(LightTransition(from: .red, event: .next, to: .green))

        // A transition back to the same state.
        try expectUnchangedWhenSaved(LightTransition(from: .dark, event: .fail, to: .dark))
    }

    @Test func transitionIsUnchangedWhenSavedWhateverTheTypes() throws {
        try expectUnchangedWhenSaved(StateTransition<Switch, Switch>(from: .off, event: .on, to: .on))
        try expectUnchangedWhenSaved(StateTransition<String, Int>(from: 1, event: "one more", to: 2))
    }

    @Test func transitionIsSavedWithTheNamesOfItsPropertiesAsKeys() throws {
        let transition = LightTransition(from: .red, event: .next, to: .green)

        #expect(try json(transition) == #"{"event":"next","from":"red","to":"green"}"#)
    }

    @Test func transitionIsReadFromTheSavedFormat() throws {
        // Written by hand, and not by encoding, to be what is already saved somewhere.
        let saved = #"{"from": "amber", "event": "fail", "to": "dark"}"#

        #expect(try decoded(LightTransition.self, from: saved) == StateTransition(from: .amber, event: .fail, to: .dark))
    }

    @Test(arguments: ["from", "event", "to"])
    func transitionWithoutOneOfItsKeysIsNotRead(missingKey: String) throws {
        var saved = ["from": "red", "event": "next", "to": "green"]
        saved[missingKey] = nil

        let error = try #require(throws: DecodingError.self) {
            try decoded(LightTransition.self, from: json(saved))
        }

        guard case .keyNotFound(let key, _) = error else {
            Issue.record("Expected a key to be missing, but got: \(error)")
            return
        }
        #expect(key.stringValue == missingKey)
    }

    @Test func transitionWithUnknownStateIsNotRead() throws {
        // A state removed from the enumeration after the transition was saved.
        let saved = #"{"from": "red", "event": "next", "to": "blue"}"#

        #expect(throws: DecodingError.self) {
            try decoded(LightTransition.self, from: saved)
        }
    }

    // MARK: - Rejected events

    @Test func rejectedEventIsUnchangedWhenSaved() throws {
        try expectUnchangedWhenSaved(LightRejectedEvent(event: .next, state: .dark))
        try expectUnchangedWhenSaved(RejectedEvent<String, Int>(event: "one more", state: 2))
    }

    @Test func rejectedEventIsSavedWithTheNamesOfItsPropertiesAsKeys() throws {
        let rejectedEvent = LightRejectedEvent(event: .next, state: .dark)

        #expect(try json(rejectedEvent) == #"{"event":"next","state":"dark"}"#)
    }

    @Test func rejectedEventIsReadFromTheSavedFormat() throws {
        let saved = #"{"state": "dark", "event": "fail"}"#

        #expect(try decoded(LightRejectedEvent.self, from: saved) == RejectedEvent(event: .fail, state: .dark))
    }

    @Test(arguments: ["event", "state"])
    func rejectedEventWithoutOneOfItsKeysIsNotRead(missingKey: String) throws {
        var saved = ["event": "next", "state": "dark"]
        saved[missingKey] = nil

        let error = try #require(throws: DecodingError.self) {
            try decoded(LightRejectedEvent.self, from: json(saved))
        }

        guard case .keyNotFound(let key, _) = error else {
            Issue.record("Expected a key to be missing, but got: \(error)")
            return
        }
        #expect(key.stringValue == missingKey)
    }

    // MARK: - The log

    /// A log of the numbers from one up to a number, appended in order.
    private func makeLog(upTo newest: Int, capacity: UInt?) -> CapacityLog<Int> {
        var log = CapacityLog<Int>(capacity: capacity)
        for number in stride(from: 1, through: newest, by: 1) {
            log.append(number)
        }
        return log
    }

    /// A log encoded and decoded again, as JSON and as a property list.
    private func savedAndRead(_ log: CapacityLog<Int>) throws -> [CapacityLog<Int>] {
        [
            try JSONDecoder().decode(CapacityLog<Int>.self, from: JSONEncoder().encode(log)),
            try PropertyListDecoder().decode(CapacityLog<Int>.self, from: PropertyListEncoder().encode(log)),
        ]
    }

    @Test func logIsSavedWithItsCapacityAndItsElements() throws {
        // Five numbers were appended, and the log kept the three newest.
        #expect(try json(makeLog(upTo: 5, capacity: 3)) == #"{"capacity":3,"elements":[3,4,5]}"#)
    }

    @Test func logWithoutCapacityIsSavedWithoutOne() throws {
        #expect(try json(makeLog(upTo: 3, capacity: nil)) == #"{"elements":[1,2,3]}"#)
    }

    @Test func emptyLogIsSavedWithoutElements() throws {
        #expect(try json(makeLog(upTo: 0, capacity: 2)) == #"{"capacity":2,"elements":[]}"#)
        #expect(try json(makeLog(upTo: 0, capacity: nil)) == #"{"elements":[]}"#)
    }

    @Test func logIsReadFromTheSavedFormat() throws {
        var log = try decoded(CapacityLog<Int>.self, from: #"{"elements": [1, 2, 3], "capacity": 3}"#)
        #expect(Array(log) == [1, 2, 3])

        // The capacity is read too, so the log goes on dropping its oldest element.
        log.append(4)
        #expect(Array(log) == [2, 3, 4])
    }

    @Test func logReadWithoutCapacityKeepsEverything() throws {
        var log = try decoded(CapacityLog<Int>.self, from: #"{"elements": [1, 2, 3]}"#)
        for number in 4 ... 1_000 {
            log.append(number)
        }

        #expect(log.count == 1_000)
        #expect(log.first == 1)
    }

    @Test(arguments: [nil, 0, 1, 3, 5, 10] as [UInt?])
    func logSavedAndReadGoesOnLikeTheLogItWasSavedFrom(capacity: UInt?) throws {
        var log = makeLog(upTo: 5, capacity: capacity)
        var copies = try savedAndRead(log)

        for copy in copies {
            #expect(Array(copy) == Array(log))
        }

        // The same elements are dropped from the copies as from the log.
        for number in 6 ... 20 {
            log.append(number)
            for index in copies.indices {
                copies[index].append(number)
                #expect(Array(copies[index]) == Array(log))
            }
        }
    }

    /// What is kept of the elements one to four, by the capacity of the log.
    private static let keptByCapacity: [(capacity: UInt, kept: [Int])] = [
        (0, []), (1, [4]), (2, [3, 4]), (4, [1, 2, 3, 4]), (9, [1, 2, 3, 4]),
    ]

    @Test(arguments: keptByCapacity)
    func logReadWithMoreElementsThanItsCapacityKeepsTheNewest(capacity: UInt, kept: [Int]) throws {
        // Not written by a log. Edited by hand, or written by something else.
        let log = try decoded(CapacityLog<Int>.self, from: #"{"capacity": \#(capacity), "elements": [1, 2, 3, 4]}"#)

        #expect(Array(log) == kept)
    }

    @Test func logWithoutElementsIsNotRead() throws {
        let error = try #require(throws: DecodingError.self) {
            try decoded(CapacityLog<Int>.self, from: #"{"capacity": 2}"#)
        }

        guard case .keyNotFound(let key, _) = error else {
            Issue.record("Expected a key to be missing, but got: \(error)")
            return
        }
        #expect(key.stringValue == "elements")
    }

    @Test func logWithNegativeCapacityIsNotRead() throws {
        #expect(throws: DecodingError.self) {
            try decoded(CapacityLog<Int>.self, from: #"{"capacity": -1, "elements": []}"#)
        }
    }

    // MARK: - Saving without reading, and reading without saving

    @Test func encodableEventAndStateIsEnoughToSave() throws {
        let transition = StateTransition(from: OnlyEncodable(name: "a"), event: OnlyEncodable(name: "go"), to: OnlyEncodable(name: "b"))
        #expect(try json(transition) == #"{"event":{"name":"go"},"from":{"name":"a"},"to":{"name":"b"}}"#)

        let rejectedEvent = RejectedEvent(event: OnlyEncodable(name: "go"), state: OnlyEncodable(name: "b"))
        #expect(try json(rejectedEvent) == #"{"event":{"name":"go"},"state":{"name":"b"}}"#)
    }

    @Test func decodableEventAndStateIsEnoughToRead() throws {
        let transition = try decoded(StateTransition<OnlyDecodable, OnlyDecodable>.self,
                                     from: #"{"from": {"name": "a"}, "event": {"name": "go"}, "to": {"name": "b"}}"#)
        #expect(transition.from.name == "a")
        #expect(transition.event.name == "go")
        #expect(transition.to.name == "b")

        let rejectedEvent = try decoded(RejectedEvent<OnlyDecodable, OnlyDecodable>.self,
                                        from: #"{"event": {"name": "go"}, "state": {"name": "b"}}"#)
        #expect(rejectedEvent.event.name == "go")
        #expect(rejectedEvent.state.name == "b")
    }

    @Test func encodableElementsAreEnoughToSaveLog() throws {
        var log = CapacityLog<OnlyEncodable>(capacity: 1)
        log.append(OnlyEncodable(name: "a"))
        log.append(OnlyEncodable(name: "b"))

        #expect(try json(log) == #"{"capacity":1,"elements":[{"name":"b"}]}"#)
    }

    @Test func decodableElementsAreEnoughToReadLog() throws {
        let log = try decoded(CapacityLog<OnlyDecodable>.self, from: #"{"elements": [{"name": "a"}, {"name": "b"}]}"#)

        #expect(log.map(\.name) == ["a", "b"])
    }

    @Test func encodableEventIsEnoughToSaveTransitionMade() throws {
        let made = TransitionMade(from: 1, event: OnlyEncodable(name: "go"), to: 2)

        #expect(try json(made) == #"{"event":{"name":"go"},"from":1,"to":2}"#)
    }

    @Test func decodableEventIsEnoughToReadTransitionMade() throws {
        let made = try decoded(TransitionMade<OnlyDecodable, Int>.self, from: #"{"from": 1, "event": {"name": "go"}, "to": 2}"#)

        #expect(made.from == 1)
        #expect(made.event.name == "go")
        #expect(made.to == 2)
    }

    // MARK: - With a state machine

    /// A traffic light going around, until it fails at amber.
    private static let savedDefinition = """
        [
            {"from": "red",   "event": "next", "to": "green"},
            {"from": "green", "event": "next", "to": "amber"},
            {"from": "amber", "event": "next", "to": "red"},
            {"from": "amber", "event": "fail", "to": "dark"}
        ]
        """

    @Test func definitionIsReadAndUsedForStateMachine() async throws {
        let transitions = try decoded(Set<LightTransition>.self, from: Self.savedDefinition)
        let stateMachine = try StateMachine(transitions: transitions, initialState: .red)

        #expect(stateMachine.transitionCount == 4)
        #expect(stateMachine.endingStates == [.dark])

        for event in [LightEvent.next, .next, .fail] {
            await stateMachine.process(event)
        }
        #expect(await stateMachine.state == .dark)
    }

    @Test func definitionIsTheSameWhenSavedAndRead() throws {
        let transitions = try decoded(Set<LightTransition>.self, from: Self.savedDefinition)

        try expectUnchangedWhenSaved(transitions)
    }

    @Test func inconsistentDefinitionIsReadButMakesNoStateMachine() throws {
        // Reading does not check the transitions. Creating the state machine does.
        let saved = """
            [
                {"from": "red", "event": "next", "to": "green"},
                {"from": "red", "event": "next", "to": "amber"}
            ]
            """
        let transitions = try decoded(Set<LightTransition>.self, from: saved)
        #expect(transitions.count == 2)

        let error = try #require(throws: StateMachine<LightEvent, LightState>.DefinitionError.self) {
            try StateMachine(transitions: transitions, initialState: .red)
        }
        #expect(error.conflictingTransitions == transitions)
    }

    @Test func logAsArrayIsSavedFromTheOldestTransitionToTheNewest() async throws {
        let transitions = try decoded(Set<LightTransition>.self, from: Self.savedDefinition)
        let stateMachine = try StateMachine(transitions: transitions, initialState: .red)

        for event in [LightEvent.next, .next, .fail] {
            await stateMachine.process(event)
        }

        let log = Array(await stateMachine.transitionLog)
        #expect(try json(log) == """
            [{"event":"next","from":"red","to":"green"},\
            {"event":"next","from":"green","to":"amber"},\
            {"event":"fail","from":"amber","to":"dark"}]
            """)
        try expectUnchangedWhenSaved(log)
    }

    @Test func logOfStateMachineIsSavedWithItsCapacity() async throws {
        let transitions = try decoded(Set<LightTransition>.self, from: Self.savedDefinition)
        let stateMachine = try StateMachine(transitions: transitions, initialState: .red, logCapacity: 2)

        for event in [LightEvent.next, .next, .fail] {
            await stateMachine.process(event)
        }

        // Three transitions were made, and the log kept the two newest.
        let log = await stateMachine.transitionLog
        #expect(try json(log) == """
            {"capacity":2,"elements":[\
            {"event":"next","from":"green","to":"amber"},\
            {"event":"fail","from":"amber","to":"dark"}]}
            """)

        // The log is of transitions made, and is read as such. An event without
        // anything to carry is saved as its symbol, so the log can be read as
        // transitions of the definition too, which is what it was saved as before.
        let read = try decoded(CapacityLog<TransitionMade<LightEvent, LightState>>.self, from: json(log))
        #expect(Array(read) == Array(log))

        let readAsDefinition = try decoded(CapacityLog<LightTransition>.self, from: json(log))
        #expect(Array(readAsDefinition) == log.map(\.transition))
    }

    /// Waits for a stream, which goes on forever if the event is never delivered.
    @Test(.timeLimit(.minutes(1))) func rejectedEventFromStateMachineIsSaved() async throws {
        let transitions = try decoded(Set<LightTransition>.self, from: Self.savedDefinition)
        let stateMachine = try StateMachine(transitions: transitions, initialState: .red)
        let rejectedEvents = await stateMachine.rejectedEventStream()

        // A red light does not fail.
        await stateMachine.process(.fail)

        var iterator = rejectedEvents.makeAsyncIterator()
        let rejectedEvent = try #require(await iterator.next())
        #expect(try json(rejectedEvent) == #"{"event":"fail","state":"red"}"#)
    }
}
