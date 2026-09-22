import Testing
import MiamiStateMachine
import MiamiUI

/// Events carrying something, sent from a user interface.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct ObservablePayloadTests {

    enum SearchState {
        case empty, searching, results
    }

    /// The events of a search field. The text searched for is carried by the event.
    enum SearchEvent: StateMachineEvent, Hashable {
        case search(text: String)
        case show(count: Int)
        case clear

        enum EventSymbol {
            case search, show, clear
        }

        var eventSymbol: EventSymbol {
            switch self {
            case .search: .search
            case .show: .show
            case .clear: .clear
            }
        }
    }

    static let transitions: Set<StateTransition<SearchEvent.EventSymbol, SearchState>> = [
        StateTransition(from: .empty, event: .search, to: .searching),
        StateTransition(from: .searching, event: .show, to: .results),
        StateTransition(from: .results, event: .search, to: .searching),
        StateTransition(from: .results, event: .clear, to: .empty),
    ]

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    private func makeSearch() throws -> ObservableStateMachine<SearchEvent, SearchState> {
        ObservableStateMachine(try StateMachine(transitions: Self.transitions, initialState: .empty))
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func eventSentReachesTheStateMachineWithWhatItCarries() async throws {
        let search = try makeSearch()

        search.send(.search(text: "conga"))
        while search.state != .searching, !Task.isCancelled {
            await Task.yield()
        }

        #expect(await search.stateMachine.enteredWith?.event == .search(text: "conga"))
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func createsItsOwnStateMachineFromTransitionsInKinds() async throws {
        let search = try ObservableStateMachine<SearchEvent, SearchState>(transitions: Self.transitions, initialState: .results, logCapacity: 1)
        #expect(search.state == .results)

        // One event at a time, as only the newest state is kept for the main actor.
        search.send(.clear)
        while search.state != .empty, !Task.isCancelled {
            await Task.yield()
        }
        search.send(.search(text: "miami"))
        while search.state != .searching, !Task.isCancelled {
            await Task.yield()
        }

        #expect(await search.stateMachine.transitionLog.map(\.event) == [.search(text: "miami")])
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Test func whatAViewAsksIsAnsweredByTheKindOfEvent() throws {
        let search = try makeSearch()

        // Any text can be searched for, and nothing is shown before searching.
        #expect(search.accepts(.search(text: "")))
        #expect(search.accepts(.search(text: "rhythm")))
        #expect(search.accepts(.show(count: 3)) == false)
        #expect(search.eventsFromCurrent == [.search])
    }
}
