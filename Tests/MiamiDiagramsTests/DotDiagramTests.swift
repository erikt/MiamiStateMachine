import Foundation
import Testing
import MiamiStateMachine
import MiamiDiagrams

/// The diagram is text for another program, so the tests spell it out. That
/// Graphviz reads the text, and draws what is meant, is not tested here.
struct DotDiagramTests {

    // MARK: - Fixture

    /// A state with any description. Two states can have the same description.
    struct NamedState: Hashable, CustomStringConvertible {
        let id: Int
        let description: String
    }

    typealias NamedStateMachine = StateMachine<String, NamedState>

    /// The lines of a diagram, without the indentation.
    private func lines(of diagram: String) -> [String] {
        diagram.split(separator: "\n").map { $0.trimmingPrefix(while: \.isWhitespace).description }
    }

    // MARK: - The whole diagram

    @Test func diagramOfTheOrders() throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        // The state returned is not part of any transition, and is not drawn.
        #expect(stateMachine.dotDiagram == """
            digraph {
                rankdir=LR
                node [shape=circle]

                "[*]" [shape=point]
                "cancelled" [shape=doublecircle]
                "delivered" [shape=doublecircle]

                "[*]" -> "cart"
                "cart" -> "cancelled" [label="cancel"]
                "cart" -> "cart" [label="addItem"]
                "cart" -> "checkout" [label="checkOut"]
                "cart" -> "paid" [label="buyNow"]
                "checkout" -> "cancelled" [label="cancel"]
                "checkout" -> "cart" [label="editCart"]
                "checkout" -> "paid" [label="pay"]
                "paid" -> "cancelled" [label="cancel"]
                "paid" -> "shipped" [label="ship"]
                "shipped" -> "delivered" [label="deliver"]
            }
            """)
    }

    @Test func diagramIsTheSameWhateverOrderTheTransitionsComeIn() throws {
        let expected = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart).dotDiagram
        var generator = SeededGenerator(seed: 2026)

        // A set goes through its elements in an order depending
        // on its capacity, and on the order they were inserted in.
        for capacity in [0, 16, 64, 1_000] {
            var transitions = Set<OrderTransition>(minimumCapacity: capacity)
            for transition in OrderFixture.transitions.shuffled(using: &generator) {
                transitions.insert(transition)
            }

            #expect(try StateMachine(transitions: transitions, initialState: .cart).dotDiagram == expected)
        }
    }

    @Test func diagramWithoutEndingStatesHasNoDoubleOutline() throws {
        let stateMachine = try OrderStateMachine(transitions: [
            StateTransition(from: .cart, event: .checkOut, to: .checkout),
            StateTransition(from: .checkout, event: .editCart, to: .cart),
        ], initialState: .checkout)

        #expect(stateMachine.dotDiagram == """
            digraph {
                rankdir=LR
                node [shape=circle]

                "[*]" [shape=point]

                "[*]" -> "checkout"
                "cart" -> "checkout" [label="checkOut"]
                "checkout" -> "cart" [label="editCart"]
            }
            """)
    }

    @Test func diagramWithoutTransitionsHasTheInitialState() throws {
        let stateMachine = try OrderStateMachine(transitions: [], initialState: .cart)

        #expect(stateMachine.dotDiagram == """
            digraph {
                rankdir=LR
                node [shape=circle]

                "[*]" [shape=point]
                "cart" [shape=doublecircle]

                "[*]" -> "cart"
            }
            """)
    }

    @Test func nodesAndArrowsAreSorted() throws {
        let start = NamedState(id: 0, description: "start")

        // Many ending states, as a few could come out sorted without being sorted.
        let endings = ["j", "c", "h", "a", "f", "i", "b", "e", "g", "d"]
        let transitions = endings.enumerated().map { number, ending in
            StateTransition(from: start, event: "to \(ending)", to: NamedState(id: number + 1, description: ending))
        }
        let stateMachine = try NamedStateMachine(transitions: Set(transitions), initialState: start)
        let lines = lines(of: stateMachine.dotDiagram)

        #expect(lines.filter { $0.hasSuffix("[shape=doublecircle]") } == endings.sorted().map {
            #""\#($0)" [shape=doublecircle]"#
        })
        #expect(lines.filter { $0.hasPrefix(#""start" ->"#) } == endings.sorted().map {
            #""start" -> "\#($0)" [label="to \#($0)"]"#
        })
    }

    // MARK: - The initial state

    @Test(arguments: [OrderState.cart, .paid, .delivered])
    func arrowFromThePointLeadsToTheInitialState(initialState: OrderState) throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: initialState)
        let arrowsFromThePoint = lines(of: stateMachine.dotDiagram).filter { $0.hasPrefix(#""[*]" ->"#) }

        #expect(arrowsFromThePoint == [#""[*]" -> "\#(initialState)""#])
    }

    @Test func initialStateNotPartOfAnyTransitionIsDrawn() throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .returned)
        let lines = lines(of: stateMachine.dotDiagram)

        // Nothing leads from it, so it is an ending state as well.
        #expect(lines.contains(#""returned" [shape=doublecircle]"#))
        #expect(lines.contains(#""[*]" -> "returned""#))
        #expect(lines.contains(#""cart" -> "checkout" [label="checkOut"]"#))
    }

    // MARK: - Arrows

    @Test func eventsBetweenTheSameStatesShareOneArrow() throws {
        let transitions = OrderFixture.transitions.union([
            StateTransition(from: .paid, event: .shipOnInvoice, to: .shipped),
            StateTransition(from: .paid, event: .shipExpress, to: .shipped),
        ])
        let stateMachine = try StateMachine(transitions: transitions, initialState: .cart)
        let arrows = lines(of: stateMachine.dotDiagram).filter { $0.hasPrefix(#""paid" -> "shipped""#) }

        #expect(arrows == [#""paid" -> "shipped" [label="ship, shipExpress, shipOnInvoice"]"#])
    }

    @Test func eventsOfAnArrowAreSorted() throws {
        let one = NamedState(id: 1, description: "one")
        let two = NamedState(id: 2, description: "two")

        // Many events, as a few could come out sorted without being sorted.
        let events = ["j", "c", "h", "a", "f", "i", "b", "e", "g", "d"]
        let stateMachine = try NamedStateMachine(
            transitions: Set(events.map { StateTransition(from: one, event: $0, to: two) }),
            initialState: one)

        #expect(lines(of: stateMachine.dotDiagram).contains(#""one" -> "two" [label="a, b, c, d, e, f, g, h, i, j"]"#))
    }

    @Test func statesConnectedBothWaysHaveAnArrowEachWay() throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let lines = lines(of: stateMachine.dotDiagram)

        #expect(lines.contains(#""cart" -> "checkout" [label="checkOut"]"#))
        #expect(lines.contains(#""checkout" -> "cart" [label="editCart"]"#))
    }

    // MARK: - The current state

    /// How the node of the current state is marked.
    private let mark = "style=filled, fillcolor=gold"

    @Test func diagramWithCurrentStateMarksTheInitialStateAtFirst() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        #expect(await stateMachine.dotDiagramWithCurrentState == """
            digraph {
                rankdir=LR
                node [shape=circle]

                "[*]" [shape=point]
                "cancelled" [shape=doublecircle]
                "cart" [style=filled, fillcolor=gold]
                "delivered" [shape=doublecircle]

                "[*]" -> "cart"
                "cart" -> "cancelled" [label="cancel"]
                "cart" -> "cart" [label="addItem"]
                "cart" -> "checkout" [label="checkOut"]
                "cart" -> "paid" [label="buyNow"]
                "checkout" -> "cancelled" [label="cancel"]
                "checkout" -> "cart" [label="editCart"]
                "checkout" -> "paid" [label="pay"]
                "paid" -> "cancelled" [label="cancel"]
                "paid" -> "shipped" [label="ship"]
                "shipped" -> "delivered" [label="deliver"]
            }
            """)
    }

    @Test func markFollowsTheStateMachine() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        // The state machine is at an ending state last, which keeps its double outline.
        let steps: [(event: OrderEvent, markedNode: String)] = [
            (.addItem, #""cart" [\#(mark)]"#),
            (.checkOut, #""checkout" [\#(mark)]"#),
            (.pay, #""paid" [\#(mark)]"#),
            (.ship, #""shipped" [\#(mark)]"#),
            (.deliver, #""delivered" [shape=doublecircle, \#(mark)]"#),
        ]

        for step in steps {
            await stateMachine.process(step.event)
            let markedNodes = lines(of: await stateMachine.dotDiagramWithCurrentState).filter { $0.contains("fillcolor") }

            #expect(markedNodes == [step.markedNode])
        }
    }

    @Test func rejectedEventDoesNotMoveTheMark() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let before = await stateMachine.dotDiagramWithCurrentState

        // An order in the cart cannot be shipped.
        await stateMachine.process(.ship)

        #expect(await stateMachine.dotDiagramWithCurrentState == before)
    }

    @Test func diagramWithCurrentStateIsTheDiagramWithOneNodeMarked() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let diagram = lines(of: stateMachine.dotDiagram)

        for event in [OrderEvent.checkOut, .pay, .ship, .deliver] {
            await stateMachine.process(event)

            // A node only there for the mark is removed, and any other node loses the mark.
            let unmarked = lines(of: await stateMachine.dotDiagramWithCurrentState)
                .filter { !$0.hasSuffix(" [\(mark)]") }
                .map { $0.replacingOccurrences(of: ", \(mark)", with: "") }

            #expect(unmarked == diagram)
        }
    }

    @Test func diagramOfTheDefinitionMarksNothing() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let before = stateMachine.dotDiagram

        await stateMachine.process(.checkOut)

        #expect(stateMachine.dotDiagram == before)
        #expect(stateMachine.dotDiagram.contains("fillcolor") == false)
    }

    @Test func markComesAfterTheLabelOfANode() async throws {
        // The initial state is named like the point, so its node has a label.
        let star = NamedState(id: 1, description: "[*]")
        let stateMachine = try NamedStateMachine(transitions: [], initialState: star)

        #expect(lines(of: await stateMachine.dotDiagramWithCurrentState)
            .contains(#""[*] (2)" [label="[*]", shape=doublecircle, \#(mark)]"#))
    }

    // MARK: - Descriptions needing care

    @Test func quotesBackslashesAndLineBreaksAreEscaped() throws {
        let quote = NamedState(id: 1, description: #"say "hi""#)
        let slash = NamedState(id: 2, description: #"back\slash"#)
        let lines = NamedState(id: 3, description: "two\nlines")
        let carriage = NamedState(id: 4, description: "carriage\r\nreturn")

        let stateMachine = try NamedStateMachine(transitions: [
            StateTransition(from: quote, event: #"a "quoted" event"#, to: slash),
            StateTransition(from: slash, event: "line\nbreak", to: lines),
            StateTransition(from: lines, event: #"back\slash"#, to: carriage),
        ], initialState: quote)

        #expect(stateMachine.dotDiagram == #"""
            digraph {
                rankdir=LR
                node [shape=circle]

                "[*]" [shape=point]
                "carriage\nreturn" [shape=doublecircle]

                "[*]" -> "say \"hi\""
                "back\\slash" -> "two\nlines" [label="line\nbreak"]
                "say \"hi\"" -> "back\\slash" [label="a \"quoted\" event"]
                "two\nlines" -> "carriage\nreturn" [label="back\\slash"]
            }
            """#)
    }

    @Test func descriptionLookingLikeHTMLIsStillQuoted() throws {
        // Graphviz reads a label inside angle brackets as HTML, unless it is quoted.
        let bold = NamedState(id: 1, description: "<b>bold</b>")
        let stateMachine = try NamedStateMachine(transitions: [], initialState: bold)

        #expect(lines(of: stateMachine.dotDiagram).contains(#""<b>bold</b>" [shape=doublecircle]"#))
    }

    /// A chain of states with the descriptions, the first being the initial state.
    private func makeChain(of descriptions: [String]) throws -> NamedStateMachine {
        let states = descriptions.enumerated().map { NamedState(id: $0, description: $1) }
        let transitions = zip(states, states.dropFirst()).map { StateTransition(from: $0, event: "go", to: $1) }
        return try StateMachine(transitions: Set(transitions), initialState: states[0])
    }

    @Test func signJoinedWithAnotherScalarIsStillEscaped() throws {
        // A quote and the accent after it are one character, which is not a quote.
        // Neither is a backslash with an accent, or a quote after an Arabic number sign.
        let stateMachine = try makeChain(of: ["say \"\u{0301}hi\"", "back\\\u{0301}slash", "\u{0600}\"x"])
        let lines = lines(of: stateMachine.dotDiagram)

        #expect(lines.contains("\"[*]\" -> \"say \\\"\u{0301}hi\\\"\""))
        #expect(lines.contains("\"back\\\\\u{0301}slash\" -> \"\u{0600}\\\"x\" [label=\"go\"]"))
    }

    @Test func ampersandIsWrittenAsAnEntity() throws {
        // Graphviz reads entities in the text it draws, so these two would be drawn the same.
        let stateMachine = try makeChain(of: ["R&D", "R&amp;D"])

        #expect(lines(of: stateMachine.dotDiagram).contains(#""R&amp;D" -> "R&amp;amp;D" [label="go"]"#))
    }

    @Test func controlCharacterIsWrittenAsASpace() throws {
        // Graphviz does not read a file with a null character in it.
        let stateMachine = try makeChain(of: ["null\u{0}here", "bell\u{7}here", "tab\there"])
        let lines = lines(of: stateMachine.dotDiagram)

        #expect(lines.contains(#""bell here" -> "tab here" [label="go"]"#))
        #expect(lines.contains(#""null here" -> "bell here" [label="go"]"#))
        #expect(stateMachine.dotDiagram.unicodeScalars.allSatisfy { $0.properties.generalCategory != .control || $0 == "\n" })
    }

    @Test func statesWrittenTheSameWayAreDifferentNodes() throws {
        // Every kind of line break is written the same way, so the descriptions differ but not the names.
        let stateMachine = try makeChain(of: ["a\nb", "a\r\nb", "a\u{2028}b", "a\u{85}b"])
        let lines = lines(of: stateMachine.dotDiagram)
        let names = [#""a\nb""#, #""a\nb (2)""#, #""a\nb (3)""#, #""a\nb (4)""#]

        // Four nodes in a chain, and not one node with arrows to itself.
        let arrows = lines.filter { $0.contains("->") && !$0.hasPrefix(#""[*]""#) }
        #expect(arrows.count == 3)
        for arrow in arrows {
            let ends = names.filter { arrow.hasPrefix($0 + " ->") || arrow.contains("-> " + $0 + " [") }
            #expect(ends.count == 2, "An arrow should connect two different nodes: \(arrow)")
        }
        #expect(names.dropFirst().allSatisfy { name in lines.contains { $0.hasPrefix(name + " [label=\"a\\nb\"") } })
    }

    @Test func manyStatesWithTheSameDescriptionAreNumberedInOrder() throws {
        let stateMachine = try makeChain(of: Array(repeating: "same", count: 12))
        let names = Set(lines(of: stateMachine.dotDiagram).filter { $0.contains("[label=\"same\"") }.map { $0.prefix { $0 != "[" }.dropLast() })

        #expect(names == Set((2 ... 12).map { "\"same (\($0))\"" }))
    }

    // MARK: - States with the same description

    @Test func statesWithTheSameDescriptionAreDifferentNodes() throws {
        let start = NamedState(id: 1, description: "start")
        let twinA = NamedState(id: 2, description: "twin")
        let twinB = NamedState(id: 3, description: "twin")

        let stateMachine = try NamedStateMachine(transitions: [
            StateTransition(from: start, event: "to a", to: twinA),
            StateTransition(from: start, event: "to b", to: twinB),
        ], initialState: start)
        let lines = lines(of: stateMachine.dotDiagram)

        // One of them is named by the description alone. The other has a number
        // added to its name, and the description as its label.
        #expect(lines.contains(#""twin" [shape=doublecircle]"#))
        #expect(lines.contains(#""twin (2)" [label="twin", shape=doublecircle]"#))

        // Which one has the number is not decided, but each has its own arrow.
        let arrows = Set(lines.filter { $0.hasPrefix(#""start" ->"#) })
        let possibleArrows: [Set<String>] = [
            [#""start" -> "twin" [label="to a"]"#, #""start" -> "twin (2)" [label="to b"]"#],
            [#""start" -> "twin" [label="to b"]"#, #""start" -> "twin (2)" [label="to a"]"#],
        ]
        #expect(possibleArrows.contains(arrows))
    }

    @Test func stateNamedLikeThePointIsADifferentNode() throws {
        let star = NamedState(id: 1, description: "[*]")
        let end = NamedState(id: 2, description: "end")

        let stateMachine = try NamedStateMachine(transitions: [
            StateTransition(from: star, event: "go", to: end),
        ], initialState: star)

        #expect(stateMachine.dotDiagram == """
            digraph {
                rankdir=LR
                node [shape=circle]

                "[*]" [shape=point]
                "[*] (2)" [label="[*]"]
                "end" [shape=doublecircle]

                "[*]" -> "[*] (2)"
                "[*] (2)" -> "end" [label="go"]
            }
            """)
    }

    @Test func numberedNameAlreadyTakenIsNumberedAgain() throws {
        // The second twin would be named like the third state is described.
        let twinA = NamedState(id: 1, description: "twin")
        let twinB = NamedState(id: 2, description: "twin")
        let numbered = NamedState(id: 3, description: "twin (2)")

        let stateMachine = try NamedStateMachine(transitions: [
            StateTransition(from: twinA, event: "go", to: twinB),
            StateTransition(from: twinB, event: "go", to: numbered),
        ], initialState: twinA)
        let lines = lines(of: stateMachine.dotDiagram)

        // The twins come first by their descriptions, and take both names.
        #expect(lines.contains(#""twin (2) (2)" [label="twin (2)", shape=doublecircle]"#))
        #expect(lines.contains(#""twin (2)" [label="twin"]"#))
        #expect(lines.filter { $0.contains("->") }.count == 3)
    }
}
