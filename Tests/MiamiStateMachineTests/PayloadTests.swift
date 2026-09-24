import Foundation
import Testing
import MiamiStateMachine

/// Events carrying something. The definition is written in event triggers,
/// and what an event carries is delivered with it, without being looked at.
@Suite(.timeLimit(.minutes(1)))
struct PayloadTests {

    // MARK: - Fixture

    enum LoadState: String, Codable {
        case idle, loading, ready, failed
    }

    /// The events of loading something. Two of them carry something.
    enum LoadEvent: StateMachineEvent, Hashable, Codable {
        case start
        case finish(bytes: Int)
        case fail(reason: String)
        case retry

        enum EventTrigger: String, Codable {
            case start, finish, fail, retry
        }

        var eventTrigger: EventTrigger {
            switch self {
            case .start: .start
            case .finish: .finish
            case .fail: .fail
            case .retry: .retry
            }
        }
    }

    typealias LoadTransition = TransitionRule<LoadEvent.EventTrigger, LoadState>
    typealias LoadStateMachine = StateMachine<LoadEvent, LoadState>

    /// Loading can fail and be tried again. Ready is an ending state.
    static let transitions: Set<LoadTransition> = [
        TransitionRule(from: .idle, event: .start, to: .loading),
        TransitionRule(from: .loading, event: .finish, to: .ready),
        TransitionRule(from: .loading, event: .fail, to: .failed),
        TransitionRule(from: .failed, event: .retry, to: .loading),
    ]

    private func makeStateMachine(logCapacity: UInt? = nil) throws -> LoadStateMachine {
        try StateMachine(transitions: Self.transitions, initialState: .idle, logCapacity: logCapacity)
    }

    // MARK: - Processing

    @Test func eventIsDeliveredWithWhatItCarries() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.start)

        let made = try #require(await stateMachine.process(.finish(bytes: 512)))

        #expect(made == TransitionEvent(from: .loading, event: .finish(bytes: 512), to: .ready))
        #expect(await stateMachine.state == .ready)

        // What is carried comes out with its type, without any casting.
        guard case .finish(let bytes) = made.event else {
            Issue.record("Expected the event finish, but got \(made.event)")
            return
        }
        #expect(bytes == 512)
    }

    @Test func transitionEventHasTheTransitionOfTheDefinition() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.start)

        let made = try #require(await stateMachine.process(.fail(reason: "No connection")))

        #expect(made.rule == TransitionRule(from: .loading, event: .fail, to: .failed))
        #expect(Self.transitions.contains(made.rule))
    }

    @Test(arguments: [0, 1, 512, Int.max])
    func whatIsCarriedDoesNotDecideTheTransition(bytes: Int) async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.start)

        let made = await stateMachine.process(.finish(bytes: bytes))

        #expect(made?.to == .ready)
    }

    @Test func rejectedEventKeepsWhatItCarries() async throws {
        let stateMachine = try makeStateMachine()
        let rejectedEvents = await stateMachine.rejectedEventStream()

        // Nothing is loading yet, so nothing can have failed.
        #expect(await stateMachine.process(.fail(reason: "Too early")) == nil)

        var iterator = rejectedEvents.makeAsyncIterator()
        let rejected = await iterator.next()
        #expect(rejected == RejectedEvent(event: .fail(reason: "Too early"), state: .idle))
    }

    // MARK: - The transition made as a value

    @Test func transitionEventIsDescribedWithItsEvent() {
        let made = TransitionEvent<LoadEvent, LoadState>(from: .loading, event: .finish(bytes: 512), to: .ready)

        #expect(made.description == "loading --(finish(bytes: 512))--> ready")
    }

    @Test func whatIsCarriedIsPartOfATransitionEvent() {
        let made = TransitionEvent<LoadEvent, LoadState>(from: .loading, event: .finish(bytes: 1), to: .ready)
        let other = TransitionEvent<LoadEvent, LoadState>(from: .loading, event: .finish(bytes: 2), to: .ready)

        // The same transition of the definition, but not the same transition made.
        #expect(made.rule == other.rule)
        #expect(made != other)
        #expect(Set([made, other, made]).count == 2)
    }

    @Test func whatIsCarriedIsPartOfARejectedEvent() {
        let rejected = RejectedEvent<LoadEvent, LoadState>(event: .fail(reason: "a"), state: .idle)
        let other = RejectedEvent<LoadEvent, LoadState>(event: .fail(reason: "b"), state: .idle)

        #expect(rejected != other)
        #expect(Set([rejected, other, rejected]).count == 2)
    }

    // MARK: - Streams and the log

    @Test func streamLogAndEnteredWithHaveTheEventsProcessed() async throws {
        let stateMachine = try makeStateMachine()
        let stream = await stateMachine.transitionStream()

        let events: [LoadEvent] = [.start, .fail(reason: "Timeout"), .retry, .finish(bytes: 2_048)]
        for event in events {
            await stateMachine.process(event)
        }

        // The stream finishes at ready, an ending state.
        var streamed: [LoadEvent] = []
        for await made in stream {
            streamed.append(made.event)
        }

        #expect(streamed == events)
        #expect(await stateMachine.transitionLog.map(\.event) == events)
        #expect(await stateMachine.enteredWith?.event == .finish(bytes: 2_048))
    }

    // MARK: - The definition

    @Test func definitionIsAskedInTriggers() async throws {
        let stateMachine = try makeStateMachine()

        #expect(stateMachine.events(from: .loading) == [.finish, .fail])
        #expect(stateMachine.transition(from: .failed, for: .retry) == TransitionRule(from: .failed, event: .retry, to: .loading))
        #expect(stateMachine.shortestPath(from: .idle, to: .ready)?.map(\.event) == [.start, .finish])
        #expect(stateMachine.endingStates == [.ready])

        await stateMachine.process(.start)
        #expect(await stateMachine.eventsFromCurrent == [.finish, .fail])
    }

    @Test func conflictIsBetweenTriggers() throws {
        // Loaded cannot lead from loading to two states, whatever it carries.
        let conflict = TransitionRule<LoadEvent.EventTrigger, LoadState>(from: .loading, event: .finish, to: .failed)

        let error = try #require(throws: LoadStateMachine.DefinitionError.self) {
            try LoadStateMachine(transitions: Self.transitions.union([conflict]), initialState: .idle)
        }

        #expect(error.conflictingTransitions == [conflict, TransitionRule(from: .loading, event: .finish, to: .ready)])
    }

    // MARK: - Events of other sorts

    /// An event that cannot be compared or hashed, because of what it carries.
    struct Message: StateMachineEvent {
        struct Attachment: Sendable {
            let data: [UInt8]
        }

        enum EventTrigger {
            case received
        }

        let attachment: Attachment
        var eventTrigger: EventTrigger { .received }
    }

    @Test func eventDoesNotHaveToBeHashable() async throws {
        let stateMachine = try StateMachine<Message, Int>(transitions: [
            TransitionRule(from: 0, event: .received, to: 1),
        ], initialState: 0)

        let made = await stateMachine.process(Message(attachment: .init(data: [1, 2, 3])))

        #expect(made?.event.attachment.data == [1, 2, 3])
        #expect(made?.to == 1)
    }

    /// The rejected event cannot be compared, but it is thrown with what it carries.
    @Test func eventThatCannotBeComparedIsThrownWithWhatItCarries() async throws {
        let stateMachine = try StateMachine<Message, Int>(transitions: [], initialState: 0)

        do {
            try await stateMachine.processOrThrow(Message(attachment: .init(data: [4, 5])))
            Issue.record("A state machine without transitions rejects every event.")
        } catch {
            #expect(error.event.attachment.data == [4, 5])
            #expect(error.state == 0)
        }
    }

    @Test func eventWithoutAnythingToCarryIsItsOwnTrigger() async throws {
        // The type of the events is known from the transitions, as before.
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        let made = try #require(await stateMachine.process(.checkOut))

        #expect(made.event == .checkOut)
        #expect(made.event.eventTrigger == .checkOut)
        #expect(made.rule == TransitionRule(from: .cart, event: .checkOut, to: .checkout))
    }

    @Test func stringsAndIntegersAreEventsAsTheyAre() async throws {
        let byString = try StateMachine(transitions: [TransitionRule(from: 0, event: "go", to: 1)], initialState: 0)
        let byInteger = try StateMachine(transitions: [TransitionRule(from: "a", event: 7, to: "b")], initialState: "a")

        #expect(await byString.process("go")?.to == 1)
        #expect(await byInteger.process(7)?.to == "b")
    }

    // MARK: - Saving

    /// A value encoded as JSON, with the keys sorted to be the same every time.
    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test func transitionEventIsSavedWithWhatItsEventCarries() throws {
        let made = TransitionEvent<LoadEvent, LoadState>(from: .loading, event: .finish(bytes: 512), to: .ready)

        #expect(try json(made) == #"{"event":{"finish":{"bytes":512}},"from":"loading","to":"ready"}"#)

        let read = try JSONDecoder().decode(TransitionEvent<LoadEvent, LoadState>.self, from: Data(try json(made).utf8))
        #expect(read == made)
    }

    @Test func logIsSavedWithWhatItsEventsCarry() async throws {
        let stateMachine = try makeStateMachine(logCapacity: 2)
        for event in [LoadEvent.start, .fail(reason: "Timeout"), .retry] {
            await stateMachine.process(event)
        }

        let log = await stateMachine.transitionLog
        #expect(try json(log) == """
            {"capacity":2,"elements":[\
            {"event":{"fail":{"reason":"Timeout"}},"from":"loading","to":"failed"},\
            {"event":{"retry":{}},"from":"failed","to":"loading"}]}
            """)

        let read = try JSONDecoder().decode(CapacityLog<TransitionEvent<LoadEvent, LoadState>>.self, from: Data(try json(log).utf8))
        #expect(Array(read) == Array(log))
    }

    @Test func definitionIsSavedInTriggers() throws {
        let saved = #"[{"from": "idle", "event": "start", "to": "loading"}, {"from": "loading", "event": "finish", "to": "ready"}]"#

        let transitions = try JSONDecoder().decode(Set<LoadTransition>.self, from: Data(saved.utf8))

        #expect(transitions.isSubset(of: Self.transitions))
        #expect(transitions.count == 2)
    }
}
