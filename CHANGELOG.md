# Changelog

All changes to MiamiStateMachine that users of the package will notice. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the versions follow
[Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- `TransitionRule.from(allExcept:event:to:)` and `TransitionRule.atEveryState(event:)`, for states that are
  `CaseIterable`. They make the rules for the same event from many states, like an event breaking a machine down at any
  state, to put together with the rest of the definition.

### Changed

- The package declares tvOS 18, watchOS 11 and visionOS 2, besides macOS 15 and iOS 18. They were not declared before,
  so the oldest version a client's Xcode supports was the minimum. Xcode 27 already builds the package for these
  versions, but a client building for older versions of them with Xcode 26 is now refused.
- `ObservableStateMachine` is no longer marked with `@available`, as every platform of the package has Observation.

## [3.2.0] - 2026-09-24

### Added

- `wait(for:)` on `StateMachine`, which waits until the state machine is at a state, and returns if it got there. It
  returns false when the state can no longer be reached, like at another ending state, or when the task is cancelled.
- Signposts showing a state machine in Instruments: every state as an interval, ended by the trigger of the event
  leaving it, and every rejected event as a signpost event, with a lane for each state machine. They are only written
  while Instruments records them, with `MiamiStateMachine` added to the subsystems for dynamic tracing of the
  os_signpost instrument.
- `processOrThrow(_:)` on `StateMachine`, which processes an event like `process(_:)`, and throws the event as a
  `RejectedEvent` if it is rejected, with typed throws. `RejectedEvent` is now an `Error`, and a `LocalizedError`.

## [3.1.0] - 2026-09-24

### Added

- The documentation of the four libraries, generated with DocC, at
  [erikt.github.io/MiamiStateMachine](https://erikt.github.io/MiamiStateMachine/).
- `process(_:)` on `ObservableStateMachine`, which processes an event after the events already sent and returns the
  transition made, or nil if the event was rejected.
- An example in `examples/VendingMachine`: a vending machine with a server and a command line client, using the macro
  `@StateMachineEvent`, events carrying values, and diagrams. Its README tells how to build and run it.

## [3.0.0] - 2026-09-23

### Changed

- **Breaking:** `StateTransition`, a rule of the definition, is renamed to `TransitionRule`.
- **Breaking:** `TransitionMade`, a transition made when an event was processed, is renamed to `TransitionEvent`. Its
  property `transition` is renamed to `rule`.
- **Breaking:** The associated type `EventSymbol` of `StateMachineEvent` is renamed to `EventTrigger`, and the property
  `eventSymbol` to `eventTrigger`.

- `transitions(to:)`, `transitions(to:for:)` and `events(to:)` no longer go through every rule of the definition.

The saved formats do not change, as the keys are the names of the properties.

### Added

- The library `MiamiMacros`, with the macro `@StateMachineEvent`. Attached to an enumeration of events, it writes the
  triggers, the mapping from an event to its trigger, and the conformance to `StateMachineEvent`. The library needs
  swift-syntax, so only clients importing it build swift-syntax.

## [2.0.0] - 2026-09-23

Events can carry something, like the data loaded or the reason for a failure. This changes the API.

### Changed

- **Breaking:** An event type has to conform to `StateMachineEvent`. An event without anything to carry needs nothing
  more than the conformance: `enum DoorEvent: StateMachineEvent { case open, close }`.
- **Breaking:** The transitions are written in event symbols, `Event.EventSymbol`, which are the events without what
  they carry. For an event without anything to carry, the event is its own symbol, and nothing changes.
- **Breaking:** `process(_:)` returns a `TransitionMade`, with the event processed and what it carried, instead of a
  `StateTransition`. So do `transitionStream()`, the `transitionLog` and `enteredWith`. The transition of the definition
  is its `transition`.
- **Breaking:** `RejectedEvent` has the rejected event with what it carried. It is `Equatable` and `Hashable` only when
  the event is.
- **Breaking:** The questions about the definition, like `events(from:)` and `transition(from:for:)`, and the
  `conflictingTransitions` of a `DefinitionError`, are in event symbols.
- **Breaking:** `eventsFromCurrent` of `ObservableStateMachine` is a set of event symbols. `accepts(_:)` only looks at
  the symbol of the event.
- The log keeps the events with what they carry. Give it a capacity when that is much.

### Added

- `StateMachineEvent`, with the associated type `EventSymbol` and the property `eventSymbol`.
- `TransitionMade`, a transition made, with the event itself. It is `Codable` with the same keys as a
  `StateTransition`, so a log of events without anything to carry is saved as before.
- `String` and `Int` are events as they are.

### Fixed

- The diagrams escape their text by Unicode scalar. A quote, a backslash or another sign followed by a combining mark
  was written as it is, and a DOT file with it could not be read by Graphviz.
- The DOT diagram writes an ampersand as `&amp;` and a control character as a space. States differing only in the kind
  of line break are different nodes. Many states with the same description are named without slowing down.
- The Mermaid diagram also guards against the word `direction` followed by a byte order mark, or joined to the character
  before it.

The text of a diagram only changes for descriptions with such characters.

## [1.0.0] - 2026-09-21

The first version with a stable API.

### Added

- The library `MiamiDiagrams`, with the definition of a state machine as a diagram: `dotDiagram` for Graphviz and
  `mermaidDiagram` for Mermaid. `dotDiagramWithCurrentState` and `mermaidDiagramWithCurrentState` mark the current
  state.
- A section in the README about how to install the package.

### Changed

- **Breaking:** The package requires macOS 15 or iOS 18, instead of macOS 12 or iOS 15.
- The package requires Swift 6.3 (Xcode 26.4), instead of Swift 6.4.

The tag was moved on the day of release to include the new requirements. If Swift Package Manager reports that the
revision of 1.0.0 does not match a recorded value, remove the entry for 1.0.0 from
`~/.swiftpm/security/fingerprints`.

## [0.3.0] - 2026-09-21

### Added

- `StateTransition` and `RejectedEvent` are `Codable` when the events and the states are. The keys are `from`, `event`
  and `to`, and `event` and `state`.
- `CapacityLog` is `Codable` when its elements are. It is saved with its capacity, under the keys `capacity` and
  `elements`.

## [0.2.0] - 2026-09-21

### Added

- `shortestPath(from:to:)` and `shortestPath(to:)`, the way from a state to another state with the fewest events.
- Checks of the definition: `states`, `endingStates`, `reachableStates(from:)`, `reachableStatesFromCurrent`,
  `unreachableStates`, `statesWithoutPathToEndingState` and `hasCycle`.
- `stateStream(bufferingPolicy:)`, a stream of the states the state machine is at, starting with the current state.
- The library `MiamiUI`, with `ObservableStateMachine`: the current state as an observable property for SwiftUI.

### Changed

- **Breaking:** The package requires Swift 6.4.
- **Breaking:** `Transition` is renamed to `StateTransition`.
- **Breaking:** Creating a state machine throws a `DefinitionError` with the transitions in conflict, instead of
  returning `nil`.
- **Breaking:** `process(_:)` returns the transition made, or `nil` if the event was rejected.
- **Breaking:** `doneTransitionStream` and `rejectedEventStream` are replaced by `transitionStream(bufferingPolicy:)`
  and `rejectedEventStream(bufferingPolicy:)`, which create a new stream for every call. A stream finishes when the
  state machine reaches an ending state, and when it is deallocated.
- **Breaking:** Rejected events are `RejectedEvent` values, instead of tuples.
- **Breaking:** `atInitialState`, `atEndingState` and `atEnd(for:)` are renamed to `isAtInitialState`,
  `isAtEndingState` and `isEndingState(_:)`. `numOfTransitions` is renamed to `transitionCount`.
- **Breaking:** `CapacityLog` is a collection, from the oldest element to the newest. Its elements do not have to be
  `Hashable`. `first`, `last`, `popFirst()` and `popLast()` replace `peekOldest`, `peek`, `popOldest()` and `pop()`.
- `initialState` can be read without waiting for the state machine.
- `enteredWith` is kept also when the log has a capacity of zero.
- `CapacityLog` is `Sendable` when its elements are.
- Processing an event takes the same time however many transitions there are.

## [0.1.0] - 2026-09-21

The state machine as it was in June 2023, tagged afterwards. It is the last version for Swift 5.6.

[Unreleased]: https://github.com/erikt/MiamiStateMachine/compare/3.2.0...HEAD
[3.2.0]: https://github.com/erikt/MiamiStateMachine/compare/3.1.0...3.2.0
[3.1.0]: https://github.com/erikt/MiamiStateMachine/compare/3.0.0...3.1.0
[3.0.0]: https://github.com/erikt/MiamiStateMachine/compare/2.0.0...3.0.0
[2.0.0]: https://github.com/erikt/MiamiStateMachine/compare/1.0.0...2.0.0
[1.0.0]: https://github.com/erikt/MiamiStateMachine/compare/0.3.0...1.0.0
[0.3.0]: https://github.com/erikt/MiamiStateMachine/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/erikt/MiamiStateMachine/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/erikt/MiamiStateMachine/tree/0.1.0
