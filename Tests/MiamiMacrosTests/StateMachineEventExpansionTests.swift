// The compiler plugin is only built for the machine building, so these
// tests are left out when building the tests for another platform.
#if canImport(MiamiMacrosPlugin)
import MiamiMacrosPlugin
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// What `@StateMachineEvent` writes, as text.
struct StateMachineEventExpansionTests {

    private let macros: [String: MacroSpec] = [
        "StateMachineEvent": MacroSpec(type: StateMachineEventMacro.self, conformances: ["StateMachineEvent"]),
    ]

    /// Checks what a macro expands to, and records any difference as an issue of the test.
    private func expect(
        _ source: String,
        expandsTo expanded: String,
        diagnostics: [DiagnosticSpec] = [],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        assertMacroExpansion(source, expandedSource: expanded, diagnostics: diagnostics, macroSpecs: macros) { failure in
            Issue.record(Comment(rawValue: failure.message), sourceLocation: sourceLocation)
        }
    }

    @Test func writesTheTriggersAndTheConformance() {
        expect("""
            @StateMachineEvent
            enum LoadEvent {
                case start
                case finish(bytes: Int)
                case fail(reason: String)
            }
            """, expandsTo: """
            enum LoadEvent {
                case start
                case finish(bytes: Int)
                case fail(reason: String)

                enum EventTrigger: Hashable, Sendable, CaseIterable, Codable {
                    case start, finish, fail
                }

                var eventTrigger: EventTrigger {
                    switch self {
                    case .start:
                        .start
                    case .finish:
                        .finish
                    case .fail:
                        .fail
                    }
                }
            }

            extension LoadEvent: MiamiStateMachine.StateMachineEvent {
            }
            """)
    }

    @Test(arguments: [("public", "public "), ("package", "package "), ("internal", ""), ("fileprivate", ""), ("private", "")])
    func triggersHaveTheAccessLevelOfTheEvents(level: String, written: String) {
        expect("""
            @StateMachineEvent
            \(level) enum DoorEvent {
                case open
            }
            """, expandsTo: """
            \(level) enum DoorEvent {
                case open

                \(written)enum EventTrigger: Hashable, Sendable, CaseIterable, Codable {
                    case open
                }

                \(written)var eventTrigger: EventTrigger {
                    switch self {
                    case .open:
                        .open
                    }
                }
            }

            extension DoorEvent: MiamiStateMachine.StateMachineEvent {
            }
            """)
    }

    @Test func keepsCasesDeclaredTogetherAndNamesInBackticks() {
        expect("""
            @StateMachineEvent
            enum Command {
                case `default`, `return`(code: Int)
                case run(String, times: Int)
            }
            """, expandsTo: """
            enum Command {
                case `default`, `return`(code: Int)
                case run(String, times: Int)

                enum EventTrigger: Hashable, Sendable, CaseIterable, Codable {
                    case `default`, `return`, run
                }

                var eventTrigger: EventTrigger {
                    switch self {
                    case .`default`:
                        .`default`
                    case .`return`:
                        .`return`
                    case .run:
                        .run
                    }
                }
            }

            extension Command: MiamiStateMachine.StateMachineEvent {
            }
            """)
    }

    @Test func eventsWithoutCasesHaveNoTriggers() {
        expect("""
            @StateMachineEvent
            enum Nothing {
            }
            """, expandsTo: """
            enum Nothing {

                enum EventTrigger: Hashable, Sendable, CaseIterable, Codable {
                }

                var eventTrigger: EventTrigger {
                    switch self {
                    }
                }
            }

            extension Nothing: MiamiStateMachine.StateMachineEvent {
            }
            """)
    }

    @Test func declaredConformanceIsNotWrittenAgain() {
        // The conformance is declared, so only the members are written.
        let macros: [String: MacroSpec] = [
            "StateMachineEvent": MacroSpec(type: StateMachineEventMacro.self, conformances: []),
        ]
        assertMacroExpansion("""
            @StateMachineEvent
            enum DoorEvent: StateMachineEvent {
                case open
            }
            """, expandedSource: """
            enum DoorEvent: StateMachineEvent {
                case open

                enum EventTrigger: Hashable, Sendable, CaseIterable, Codable {
                    case open
                }

                var eventTrigger: EventTrigger {
                    switch self {
                    case .open:
                        .open
                    }
                }
            }
            """, macroSpecs: macros) { failure in
            Issue.record(Comment(rawValue: failure.message))
        }
    }

    // MARK: - Mistakes

    @Test(arguments: ["struct", "class", "actor"])
    func onlyEnumerationsCanBeEvents(kind: String) {
        expect("""
            @StateMachineEvent
            \(kind) DoorEvent {
            }
            """, expandsTo: """
            \(kind) DoorEvent {
            }
            """, diagnostics: [
                DiagnosticSpec(message: "@StateMachineEvent can only be attached to an enumeration of events", line: 1, column: 1),
            ])
    }

    @Test(arguments: ["struct EventTrigger {\n    }", "typealias EventTrigger = DoorEvent", "var eventTrigger: DoorEvent {\n        self\n    }"])
    func triggersDeclaredAlreadyAreNotWrittenAgain(declaration: String) {
        expect("""
            @StateMachineEvent
            enum DoorEvent {
                case open
                \(declaration)
            }
            """, expandsTo: """
            enum DoorEvent {
                case open
                \(declaration)
            }

            extension DoorEvent: MiamiStateMachine.StateMachineEvent {
            }
            """, diagnostics: [
                DiagnosticSpec(message: "@StateMachineEvent writes EventTrigger and eventTrigger, which are already declared here", line: 4, column: 5),
            ])
    }
}
#endif
