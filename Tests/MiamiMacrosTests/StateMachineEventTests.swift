import Foundation
import Testing
import MiamiMacros
import MiamiStateMachine

/// Events written with `@StateMachineEvent`, used by a state machine.
@Suite(.timeLimit(.minutes(1)))
struct StateMachineEventTests {

    // MARK: - Fixture

    enum LoadState: Codable {
        case idle, loading, ready, failed
    }

    @StateMachineEvent
    enum LoadEvent: Equatable {
        case start
        case finish(bytes: Int)
        case fail(reason: String)
        case retry
    }

    /// The events are public, so the triggers are too.
    @StateMachineEvent
    public enum PublicEvent {
        case go(speed: Int)
    }

    static let rules: Set<TransitionRule<LoadEvent.EventTrigger, LoadState>> = [
        TransitionRule(from: .idle, event: .start, to: .loading),
        TransitionRule(from: .loading, event: .finish, to: .ready),
        TransitionRule(from: .loading, event: .fail, to: .failed),
        TransitionRule(from: .failed, event: .retry, to: .loading),
    ]

    // MARK: - The triggers

    @Test func everyEventHasTheTriggerOfItsCase() {
        let events: [LoadEvent] = [.start, .finish(bytes: 512), .fail(reason: "Timeout"), .retry]

        #expect(events.map(\.eventTrigger) == [.start, .finish, .fail, .retry])
    }

    @Test func triggersAreEveryCaseInOrder() {
        #expect(LoadEvent.EventTrigger.allCases == [.start, .finish, .fail, .retry])
    }

    @Test func triggersCanBeSaved() throws {
        let rule = TransitionRule<LoadEvent.EventTrigger, LoadState>(from: .loading, event: .finish, to: .ready)
        let saved = try JSONEncoder().encode(Array(Self.rules))

        #expect(try JSONDecoder().decode([TransitionRule<LoadEvent.EventTrigger, LoadState>].self, from: saved).contains(rule))
    }

    @Test func publicEventsHavePublicTriggers() {
        // Compiles only if the property and the enumeration are as public as the events.
        let trigger: PublicEvent.EventTrigger = PublicEvent.go(speed: 3).eventTrigger

        #expect(trigger == .go)
    }

    // MARK: - With a state machine

    @Test func stateMachineUsesTheTriggers() async throws {
        let stateMachine = try StateMachine<LoadEvent, LoadState>(transitions: Self.rules, initialState: .idle)
        await stateMachine.process(.start)
        await stateMachine.process(.fail(reason: "Timeout"))
        await stateMachine.process(.retry)

        let made = try #require(await stateMachine.process(.finish(bytes: 2_048)))

        #expect(made.rule == TransitionRule(from: .loading, event: .finish, to: .ready))
        #expect(made.event == .finish(bytes: 2_048))
        #expect(await stateMachine.transitionLog.map(\.event) == [.start, .fail(reason: "Timeout"), .retry, .finish(bytes: 2_048)])
    }

    @Test func whatIsCarriedDoesNotDecideTheTransition() async throws {
        let stateMachine = try StateMachine<LoadEvent, LoadState>(transitions: Self.rules, initialState: .loading)

        // Any number of bytes, as the rule is written with the trigger.
        #expect(await stateMachine.process(.finish(bytes: 0))?.to == .ready)
    }
}
