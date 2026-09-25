import Testing
import MiamiStateMachine
import MiamiDiagrams

/// The diagram is text for another program, so the tests spell it out. That
/// Mermaid reads the text, and draws what is meant, is not tested here.
struct MermaidDiagramTests {

    // MARK: - Fixture

    /// A state with any description. Two states can have the same description.
    struct NamedState: Hashable, CustomStringConvertible {
        let id: Int
        let description: String
    }

    typealias NamedStateMachine = StateMachine<String, NamedState, Void>

    /// The lines of a diagram, without the indentation.
    private func lines(of diagram: String) -> [String] {
        diagram.split(separator: "\n").map { $0.trimmingPrefix(while: \.isWhitespace).description }
    }

    /// A state machine going from a state named start to a state with a description.
    private func makeStateMachine(endingAt description: String, by event: String = "go") throws -> NamedStateMachine {
        let start = NamedState(id: 0, description: "start")
        return try StateMachine(transitions: [
            TransitionRule(from: start, event: event, to: NamedState(id: 1, description: description)),
        ], initialState: start)
    }

    // MARK: - The whole diagram

    @Test func diagramOfTheOrders() throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        // The state returned is not part of any transition, and is not drawn.
        #expect(stateMachine.mermaidDiagram == """
            stateDiagram-v2
                direction LR

                state "cancelled" as state1
                state "cart" as state2
                state "checkout" as state3
                state "delivered" as state4
                state "paid" as state5
                state "shipped" as state6

                [*] --> state2
                state2 --> state1: cancel
                state2 --> state2: addItem
                state2 --> state3: checkOut
                state2 --> state5: buyNow
                state3 --> state1: cancel
                state3 --> state2: editCart
                state3 --> state5: pay
                state5 --> state1: cancel
                state5 --> state6: ship
                state6 --> state4: deliver
                state1 --> [*]
                state4 --> [*]
            """)
    }

    @Test func diagramIsTheSameWhateverOrderTheTransitionsComeIn() throws {
        let expected = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart).mermaidDiagram
        var generator = SeededGenerator(seed: 2026)

        // A set goes through its elements in an order depending
        // on its capacity, and on the order they were inserted in.
        for capacity in [0, 16, 64, 1_000] {
            var transitions = Set<OrderTransition>(minimumCapacity: capacity)
            for transition in OrderFixture.transitions.shuffled(using: &generator) {
                transitions.insert(transition)
            }

            #expect(try StateMachine(transitions: transitions, initialState: .cart).mermaidDiagram == expected)
        }
    }

    @Test func diagramWithoutEndingStatesHasNoArrowToTheEnd() throws {
        let stateMachine = try OrderStateMachine(transitions: [
            TransitionRule(from: .cart, event: .checkOut, to: .checkout),
            TransitionRule(from: .checkout, event: .editCart, to: .cart),
        ], initialState: .checkout)

        #expect(stateMachine.mermaidDiagram == """
            stateDiagram-v2
                direction LR

                state "cart" as state1
                state "checkout" as state2

                [*] --> state2
                state1 --> state2: checkOut
                state2 --> state1: editCart
            """)
    }

    @Test func diagramWithoutTransitionsHasTheInitialState() throws {
        let stateMachine = try OrderStateMachine(transitions: [], initialState: .cart)

        #expect(stateMachine.mermaidDiagram == """
            stateDiagram-v2
                direction LR

                state "cart" as state1

                [*] --> state1
                state1 --> [*]
            """)
    }

    @Test func statesAndArrowsAreSorted() throws {
        let start = NamedState(id: 0, description: "start")

        // Many ending states, as a few could come out sorted without being sorted.
        let endings = ["j", "c", "h", "a", "f", "i", "b", "e", "g", "d"]
        let transitions = endings.enumerated().map { number, ending in
            TransitionRule(from: start, event: "to \(ending)", to: NamedState(id: number + 1, description: ending))
        }
        let stateMachine = try NamedStateMachine(transitions: Set(transitions), initialState: start)
        let lines = lines(of: stateMachine.mermaidDiagram)

        // The state named start comes last, as the eleventh. The order is by the
        // positions of the states, where state2 is before state10, and not by
        // the identifiers as text, where it is after.
        let sorted = endings.sorted()
        #expect(lines.filter { $0.hasPrefix("state \"") } == sorted.enumerated().map {
            #"state "\#($1)" as state\#($0 + 1)"#
        } + [#"state "start" as state11"#])
        #expect(lines.filter { $0.hasPrefix("state11 -->") } == sorted.enumerated().map {
            "state11 --> state\($0 + 1): to \($1)"
        })
        #expect(lines.filter { $0.hasSuffix("--> [*]") } == (1 ... 10).map { "state\($0) --> [*]" })
    }

    // MARK: - The initial state

    @Test(arguments: [(OrderState.cart, "state2"), (.paid, "state5"), (.delivered, "state4")])
    func arrowFromTheStartLeadsToTheInitialState(initialState: OrderState, identifier: String) throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: initialState)
        let arrowsFromTheStart = lines(of: stateMachine.mermaidDiagram).filter { $0.hasPrefix("[*] -->") }

        #expect(arrowsFromTheStart == ["[*] --> \(identifier)"])
    }

    @Test func initialStateNotPartOfAnyTransitionIsDrawn() throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .returned)
        let lines = lines(of: stateMachine.mermaidDiagram)

        // Nothing leads from it, so it is an ending state as well. It is the
        // sixth state by its description, which moves shipped to be the seventh.
        #expect(lines.contains(#"state "returned" as state6"#))
        #expect(lines.contains("[*] --> state6"))
        #expect(lines.contains("state6 --> [*]"))
        #expect(lines.contains(#"state "shipped" as state7"#))
    }

    // MARK: - Arrows

    @Test func eventsBetweenTheSameStatesShareOneArrow() throws {
        let transitions = OrderFixture.transitions.union([
            TransitionRule(from: .paid, event: .shipOnInvoice, to: .shipped),
            TransitionRule(from: .paid, event: .shipExpress, to: .shipped),
        ])
        let stateMachine = try StateMachine(transitions: transitions, initialState: .cart)
        let arrows = lines(of: stateMachine.mermaidDiagram).filter { $0.hasPrefix("state5 --> state6") }

        #expect(arrows == ["state5 --> state6: ship, shipExpress, shipOnInvoice"])
    }

    @Test func eventsOfAnArrowAreSorted() throws {
        let one = NamedState(id: 1, description: "one")
        let two = NamedState(id: 2, description: "two")

        // Many events, as a few could come out sorted without being sorted.
        let events = ["j", "c", "h", "a", "f", "i", "b", "e", "g", "d"]
        let stateMachine = try NamedStateMachine(
            transitions: Set(events.map { TransitionRule(from: one, event: $0, to: two) }),
            initialState: one)

        #expect(lines(of: stateMachine.mermaidDiagram).contains("state1 --> state2: a, b, c, d, e, f, g, h, i, j"))
    }

    @Test func transitionBackToTheSameStateIsAnArrowToItself() throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        #expect(lines(of: stateMachine.mermaidDiagram).contains("state2 --> state2: addItem"))
    }

    // MARK: - The current state

    @Test func diagramWithCurrentStateMarksTheInitialStateAtFirst() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        #expect(await stateMachine.mermaidDiagramWithCurrentState == """
            stateDiagram-v2
                direction LR

                state "cancelled" as state1
                state "cart" as state2
                state "checkout" as state3
                state "delivered" as state4
                state "paid" as state5
                state "shipped" as state6

                [*] --> state2
                state2 --> state1: cancel
                state2 --> state2: addItem
                state2 --> state3: checkOut
                state2 --> state5: buyNow
                state3 --> state1: cancel
                state3 --> state2: editCart
                state3 --> state5: pay
                state5 --> state1: cancel
                state5 --> state6: ship
                state6 --> state4: deliver
                state1 --> [*]
                state4 --> [*]

                classDef current fill:gold,color:black
                class state2 current
            """)
    }

    @Test func markFollowsTheStateMachine() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)

        // Through the cart, the checkout, paid and shipped to delivered, an ending state.
        let steps: [(event: OrderEvent, identifier: String)] = [
            (.addItem, "state2"), (.checkOut, "state3"), (.pay, "state5"), (.ship, "state6"), (.deliver, "state4"),
        ]

        for step in steps {
            await stateMachine.process(step.event)
            let marked = lines(of: await stateMachine.mermaidDiagramWithCurrentState).filter { $0.hasPrefix("class ") }

            #expect(marked == ["class \(step.identifier) current"])
        }
    }

    @Test func rejectedEventDoesNotMoveTheMark() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let before = await stateMachine.mermaidDiagramWithCurrentState

        // An order in the cart cannot be shipped.
        await stateMachine.process(.ship)

        #expect(await stateMachine.mermaidDiagramWithCurrentState == before)
    }

    @Test func diagramWithCurrentStateIsTheDiagramWithTheMarkAfterIt() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let diagram = stateMachine.mermaidDiagram

        for (event, identifier) in [(OrderEvent.checkOut, "state3"), (.pay, "state5"), (.ship, "state6"), (.deliver, "state4")] {
            await stateMachine.process(event)

            #expect(await stateMachine.mermaidDiagramWithCurrentState == """
                \(diagram)

                    classDef current fill:gold,color:black
                    class \(identifier) current
                """)
        }
    }

    @Test func diagramOfTheDefinitionMarksNothing() async throws {
        let stateMachine = try StateMachine(transitions: OrderFixture.transitions, initialState: .cart)
        let before = stateMachine.mermaidDiagram

        await stateMachine.process(.checkOut)

        #expect(stateMachine.mermaidDiagram == before)
        #expect(stateMachine.mermaidDiagram.contains("classDef") == false)
    }

    // MARK: - Descriptions needing care

    @Test func charactersWithMeaningToMermaidAreWrittenAsEntityCodes() throws {
        let html = NamedState(id: 1, description: "<b>bold</b>")
        let semicolon = NamedState(id: 2, description: "a;b")
        let carriage = NamedState(id: 3, description: "carriage\r\nreturn")
        let quote = NamedState(id: 4, description: #"say "hi""#)
        let lines = NamedState(id: 5, description: "two\nlines")
        let unicode = NamedState(id: 6, description: "åäö 日本")

        let stateMachine = try NamedStateMachine(transitions: [
            TransitionRule(from: quote, event: "100%", to: semicolon),
            TransitionRule(from: semicolon, event: "#1", to: html),
            TransitionRule(from: html, event: "a: b", to: lines),
            TransitionRule(from: lines, event: #"back\slash"#, to: carriage),
            TransitionRule(from: carriage, event: "{x}", to: unicode),
        ], initialState: quote)

        // A line break is written as the one piece of HTML that Mermaid draws
        // as a line break. Characters outside ASCII are written as they are.
        #expect(stateMachine.mermaidDiagram == ##"""
            stateDiagram-v2
                direction LR

                state "#60;b#62;bold#60;#47;b#62;" as state1
                state "a#59;b" as state2
                state "carriage<br/>return" as state3
                state "say #34;hi#34;" as state4
                state "two<br/>lines" as state5
                state "åäö 日本" as state6

                [*] --> state4
                state1 --> state5: a#58; b
                state2 --> state1: #35;1
                state3 --> state6: #123;x#125;
                state4 --> state2: 100#37;
                state5 --> state3: back#92;slash
                state6 --> [*]
            """##)
    }

    @Test func plainSignsAreWrittenAsTheyAre() throws {
        let description = "loading(attempt 2), it's x_y-z.w"
        let stateMachine = try makeStateMachine(endingAt: description, by: description)
        let lines = lines(of: stateMachine.mermaidDiagram)

        #expect(lines.contains(#"state "\#(description)" as state1"#))
        #expect(lines.contains("state2 --> state1: \(description)"))
    }

    @Test func signJoinedWithAnotherScalarIsStillWrittenAsAnEntityCode() throws {
        // A quote and the accent after it are one character, which is not a quote.
        // Neither is a semicolon with an accent, or a quote after an Arabic number sign.
        let description = "say \"\u{0301}hi; a;\u{0301}b \u{0600}\"x"
        let stateMachine = try makeStateMachine(endingAt: description, by: description)
        let expected = "say #34;\u{0301}hi#59; a#59;\u{0301}b \u{0600}#34;x"

        let lines = lines(of: stateMachine.mermaidDiagram)
        #expect(lines.contains("state \"\(expected)\" as state1"))
        #expect(lines.contains("state2 --> state1: \(expected)"))
    }

    /// Mermaid reads a line with the word direction and a direction after it as
    /// the direction of the whole diagram, wherever in the line it is.
    @Test(arguments: [
        ("direction LR", "direction#32;LR"),
        ("Direction TB", "Direction#32;TB"),
        ("turn in direction RL now", "turn in direction#32;RL now"),
        ("direction\u{00A0}BT", "direction#160;BT"),
        ("xdirection LRx", "xdirection#32;LRx"),
        ("direction\u{FEFF}LR", "direction#65279;LR"),
        ("\u{0600}direction LR", "\u{0600}direction#32;LR"),
        ("directions are fine", "directions are fine"),
        ("direction", "direction"),
    ])
    func spaceAfterTheWordDirectionIsWrittenAsAnEntityCode(description: String, expected: String) throws {
        let stateMachine = try makeStateMachine(endingAt: description, by: description)
        let lines = lines(of: stateMachine.mermaidDiagram)

        #expect(lines.contains { $0.hasPrefix(#"state "\#(expected)" as state"#) })
        #expect(lines.contains { $0.hasSuffix(": \(expected)") })
    }

    /// Mermaid does not read a description with nothing in it, and shows the
    /// identifier of a state with only spaces in its description.
    @Test(arguments: ["", " ", "   "])
    func descriptionWithNothingInItIsWrittenAsASpace(description: String) throws {
        let stateMachine = try makeStateMachine(endingAt: description, by: description)
        let lines = lines(of: stateMachine.mermaidDiagram)

        #expect(lines.contains(##"state "#32;" as state1"##))
        #expect(lines.contains("state2 --> state1: #32;"))
    }

    // MARK: - States with the same description

    @Test func statesWithTheSameDescriptionAreDifferentStates() throws {
        let start = NamedState(id: 1, description: "start")
        let twinA = NamedState(id: 2, description: "twin")
        let twinB = NamedState(id: 3, description: "twin")

        let stateMachine = try NamedStateMachine(transitions: [
            TransitionRule(from: start, event: "to a", to: twinA),
            TransitionRule(from: start, event: "to b", to: twinB),
        ], initialState: start)
        let lines = lines(of: stateMachine.mermaidDiagram)

        #expect(lines.contains(#"state "twin" as state2"#))
        #expect(lines.contains(#"state "twin" as state3"#))
        #expect(lines.contains("state2 --> [*]"))
        #expect(lines.contains("state3 --> [*]"))

        // Which of them is state2 is not decided, but each has its own arrow.
        let arrows = Set(lines.filter { $0.hasPrefix("state1 -->") })
        let possibleArrows: [Set<String>] = [
            ["state1 --> state2: to a", "state1 --> state3: to b"],
            ["state1 --> state2: to b", "state1 --> state3: to a"],
        ]
        #expect(possibleArrows.contains(arrows))
    }

    @Test func stateDescribedLikeAnIdentifierIsStillADifferentState() throws {
        // The state described as state1 is the second by its description.
        let stateMachine = try makeStateMachine(endingAt: "state1")

        #expect(stateMachine.mermaidDiagram == """
            stateDiagram-v2
                direction LR

                state "start" as state1
                state "state1" as state2

                [*] --> state1
                state1 --> state2: go
                state2 --> [*]
            """)
    }
}
