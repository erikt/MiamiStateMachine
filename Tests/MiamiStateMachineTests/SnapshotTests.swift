import Foundation
import Testing
import MiamiStateMachine

/// Snapshots of a state machine, and state machines restored from them. A
/// stream not working shows as a consumer waiting forever, so the time limit
/// makes it fail.
@Suite(.timeLimit(.minutes(1)))
struct SnapshotTests {

    private func makeStateMachine(logCapacity: UInt? = nil) throws -> OrderStateMachine {
        try StateMachine(transitions: OrderFixture.transitions, initialState: .cart, logCapacity: logCapacity)
    }

    /// A state machine that has added an item, checked out and paid, and had
    /// one event rejected.
    private func makePaidStateMachine(logCapacity: UInt? = nil) async throws -> OrderStateMachine {
        let stateMachine = try makeStateMachine(logCapacity: logCapacity)
        for event in [.addItem, .checkOut, .ship, .pay] as [OrderEvent] {
            await stateMachine.process(event)
        }
        return stateMachine
    }

    // MARK: - Taking a snapshot

    @Test func snapshotHoldsWhatTheStateMachineIsAt() async throws {
        let stateMachine = try await makePaidStateMachine()

        let snapshot = await stateMachine.snapshot

        #expect(snapshot.state == .paid)
        #expect(snapshot.processedEventsCount == 4)
        #expect(snapshot.stateChangeCount == 3)
        #expect(snapshot.enteredWith == TransitionEvent(from: .checkout, event: .pay, to: .paid))
        #expect(Array(snapshot.transitionLog).map(\.event) == [.addItem, .checkOut, .pay])
        #expect(snapshot.rules == OrderFixture.transitions)
    }

    // MARK: - Restoring

    @Test func restoredStateMachineGoesOnFromTheSnapshot() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot

        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .cart, restoring: snapshot)

        #expect(await restored.state == .paid)
        #expect(await restored.processedEventsCount == 4)
        #expect(await restored.stateChangeCount == 3)
        #expect(await restored.rejectedEventsCount == 1)
        #expect(await restored.enteredWith == TransitionEvent(from: .checkout, event: .pay, to: .paid))
        #expect(await Array(restored.transitionLog).map(\.event) == [.addItem, .checkOut, .pay])
        #expect(await !restored.isAtInitialState)

        #expect(await restored.process(.ship) == TransitionEvent(from: .paid, event: .ship, to: .shipped))
        #expect(await restored.stateChangeCount == 4)
    }

    @Test func snapshotBeforeAnyTransitionRestoresAtTheInitialState() async throws {
        let snapshot = await (try makeStateMachine()).snapshot

        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .cart, restoring: snapshot)

        #expect(await restored.isAtInitialState)
        #expect(await restored.enteredWith == nil)
    }

    @Test func initialStateComesFromTheArguments() async throws {
        let snapshot = await (try makeStateMachine()).snapshot

        // The snapshot is at the cart, before any transition, and the initial state is now the checkout.
        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .checkout, restoring: snapshot)

        #expect(restored.initialState == .checkout)
        #expect(await restored.state == .cart)
        #expect(await !restored.isAtInitialState)
    }

    @Test func logCapacityComesFromTheArgumentsKeepingTheNewest() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot

        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .cart, restoring: snapshot, logCapacity: 2)
        await restored.process(.ship)

        #expect(await Array(restored.transitionLog).map(\.event) == [.pay, .ship])
    }

    @Test func enteredAtIsWhenTheStateMachineWasRestored() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot

        let before = ContinuousClock.now
        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .cart, restoring: snapshot)
        let after = ContinuousClock.now

        let enteredAt = await restored.enteredAt
        #expect(before <= enteredAt && enteredAt <= after)
    }

    @Test func stateStreamStartsWithTheRestoredState() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot
        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .cart, restoring: snapshot)

        var states = await restored.stateStream().makeAsyncIterator()

        #expect(await states.next() == .paid)
    }

    @Test func stateMachineRestoredAtAnEndingStateIsAtOne() async throws {
        let stateMachine = try makeStateMachine()
        await stateMachine.process(.cancel)
        let snapshot = await stateMachine.snapshot

        let restored = try OrderStateMachine(transitions: OrderFixture.transitions, initialState: .cart, restoring: snapshot)

        #expect(await restored.isAtEndingState)
        var transitions = await restored.transitionStream().makeAsyncIterator()
        #expect(await transitions.next() == nil, "A transition stream at an ending state is finished.")
    }

    @Test func actionsGoOnChangingTheRestoredContext() async throws {
        let machine = try ContextTests.CoinMachine(initialState: .idle, context: ContextTests.Credit()) {
            ContextTests.rules
        }
        await machine.process(.insert(cents: 25))
        let snapshot = await machine.snapshot

        let restored = try ContextTests.CoinMachine(initialState: .idle, restoring: snapshot) {
            ContextTests.rules
        }
        await restored.process(.insert(cents: 10))

        #expect(await restored.context.cents == 35)
    }

    // MARK: - Rules changed since the snapshot

    @Test func rulesAddedKeepTheSnapshotRestorable() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot
        let rules = OrderFixture.transitions.union([OrderTransition(from: .paid, event: .shipExpress, to: .shipped)])

        let restored = try OrderStateMachine(transitions: rules, initialState: .cart, restoring: snapshot)

        #expect(await restored.process(.shipExpress)?.to == .shipped)
    }

    @Test func ruleRemovedMakesTheSnapshotIncompatible() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot
        let removed = OrderTransition(from: .cart, event: .buyNow, to: .paid)

        #expect(throws: OrderStateMachine.RestoreError.self) {
            try OrderStateMachine(transitions: OrderFixture.transitions.subtracting([removed]), initialState: .cart, restoring: snapshot)
        }
        do {
            _ = try OrderStateMachine(transitions: OrderFixture.transitions.subtracting([removed]), initialState: .cart, restoring: snapshot)
        } catch .incompatibleSnapshot(let missingRules) {
            #expect(missingRules == [removed])
        } catch {
            Issue.record("Expected an incompatible snapshot, not \(error).")
        }
    }

    @Test func ruleLeadingToAnotherStateMakesTheSnapshotIncompatible() async throws {
        let snapshot = await (try await makePaidStateMachine()).snapshot
        let changed = OrderTransition(from: .paid, event: .ship, to: .shipped)
        let rules = OrderFixture.transitions.subtracting([changed]).union([OrderTransition(from: .paid, event: .ship, to: .delivered)])

        do {
            _ = try OrderStateMachine(transitions: rules, initialState: .cart, restoring: snapshot)
            Issue.record("A snapshot made with another rule was restored.")
        } catch .incompatibleSnapshot(let missingRules) {
            #expect(missingRules == [changed])
        } catch {
            Issue.record("Expected an incompatible snapshot, not \(error).")
        }
    }

    @Test func conflictingRulesAreFoundWhenRestoring() async throws {
        let snapshot = await (try makeStateMachine()).snapshot
        let conflicting = OrderTransition(from: .cart, event: .cancel, to: .cart)

        do {
            _ = try OrderStateMachine(transitions: OrderFixture.transitions.union([conflicting]), initialState: .cart, restoring: snapshot)
            Issue.record("Conflicting rules were accepted.")
        } catch .conflictingRules(let error) {
            #expect(error.conflictingTransitions == [conflicting, OrderTransition(from: .cart, event: .cancel, to: .cancelled)])
        } catch {
            Issue.record("Expected conflicting rules, not \(error).")
        }
    }

    @Test func incompatibleSnapshotDescribesTheMissingRulesInOrder() {
        let error = OrderStateMachine.RestoreError.incompatibleSnapshot(missingRules: [
            OrderTransition(from: .paid, event: .ship, to: .shipped),
            OrderTransition(from: .cart, event: .buyNow, to: .paid),
        ])

        #expect(error.description == "The snapshot was made with rules that are no longer part of the definition: "
            + "cart --(buyNow)--> paid, paid --(ship)--> shipped")
        #expect(error.localizedDescription == error.description)
    }
}

// MARK: - Saving snapshots

/// Snapshots written and read, with types of their own, as the order
/// fixture is not `Codable`.
struct SnapshotCodingTests {

    enum Light: String, Codable {
        case red, green, amber
    }

    enum Change: String, StateMachineEvent, Codable {
        case go, slow, stop
    }

    struct Passes: Codable, Equatable {
        var greens = 0
    }

    /// Not `Codable`.
    struct Handle {
        var number = 7
    }

    typealias LightMachine = StateMachine<Change, Light, Void>

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private func json(_ snapshot: some Encodable) throws -> String {
        String(decoding: try encoder.encode(snapshot), as: UTF8.self)
    }

    // MARK: - The saved format

    @Test func snapshotIsSavedWithTheNamesOfItsPropertiesAsKeys() async throws {
        let lights = try LightMachine(transitions: [TransitionRule(from: .red, event: .go, to: .green)], initialState: .red)
        await lights.process(.go)

        #expect(try json(await lights.snapshot) == #"{"enteredWith":{"event":"go","from":"red","to":"green"},"#
            + #""processedEventsCount":1,"rules":[{"event":"go","from":"red","to":"green"}],"state":"green","#
            + #""stateChangeCount":1,"transitionLog":{"elements":[{"event":"go","from":"red","to":"green"}]}}"#)
    }

    @Test func snapshotBeforeAnyTransitionLeavesOutTheTransitionEnteringTheState() async throws {
        let lights = try LightMachine(transitions: [TransitionRule(from: .red, event: .go, to: .green)], initialState: .red, logCapacity: 5)

        #expect(try json(await lights.snapshot) == #"{"processedEventsCount":0,"rules":[{"event":"go","from":"red","to":"green"}],"#
            + #""state":"red","stateChangeCount":0,"transitionLog":{"capacity":5,"elements":[]}}"#)
    }

    @Test func contextIsSavedWhenItIsCodable() async throws {
        let lights = try StateMachine<Change, Light, Passes>(initialState: .red, context: Passes()) {
            From(.red) {
                On(.go, to: .green) { passes, _ in passes.greens += 1 }
            }
        }
        await lights.process(.go)

        #expect(try json(await lights.snapshot).contains(#""context":{"greens":1}"#))
    }

    @Test func contextThatIsNotCodableCannotBeSaved() async throws {
        let lights = try StateMachine<Change, Light, Handle>(transitions: [TransitionRule(from: .red, event: .go, to: .green)],
                                                             initialState: .red,
                                                             context: Handle())

        let snapshot = await lights.snapshot

        #expect(throws: EncodingError.self) {
            try encoder.encode(snapshot)
        }
    }

    // MARK: - Restoring what was saved

    @Test func savedSnapshotIsRestored() async throws {
        let lights = try StateMachine<Change, Light, Passes>(initialState: .red, context: Passes()) {
            From(.red) {
                On(.go, to: .green) { passes, _ in passes.greens += 1 }
            }
            From(.green) {
                On(.slow, to: .amber)
            }
            From(.amber) {
                On(.stop, to: .red)
            }
        }
        for change in [.go, .slow, .stop, .go] as [Change] {
            await lights.process(change)
        }

        let data = try encoder.encode(await lights.snapshot)
        let saved = try JSONDecoder().decode(StateMachine<Change, Light, Passes>.Snapshot.self, from: data)
        let restored = try StateMachine<Change, Light, Passes>(initialState: .red, restoring: saved) {
            From(.red) {
                On(.go, to: .green) { passes, _ in passes.greens += 1 }
            }
            From(.green) {
                On(.slow, to: .amber)
            }
            From(.amber) {
                On(.stop, to: .red)
            }
        }

        #expect(await restored.state == .green)
        #expect(await restored.context == Passes(greens: 2))
        #expect(await restored.stateChangeCount == 4)
        #expect(await Array(restored.transitionLog).map(\.event) == [.go, .slow, .stop, .go])
    }

    @Test func savedSnapshotWithoutAContextIsRestored() async throws {
        let rules: Set<TransitionRule<Change, Light>> = [TransitionRule(from: .red, event: .go, to: .green)]
        let lights = try LightMachine(transitions: rules, initialState: .red)
        await lights.process(.go)

        let saved = try JSONDecoder().decode(LightMachine.Snapshot.self, from: try encoder.encode(await lights.snapshot))
        let restored = try LightMachine(transitions: rules, initialState: .red, restoring: saved)

        #expect(await restored.state == .green)
        #expect(await restored.enteredWith == TransitionEvent(from: .red, event: .go, to: .green))
    }

    // MARK: - A snapshot that does not agree with itself

    /// A saved snapshot of a light turned green, with a part changed.
    private func savedSnapshot(state: String = "green",
                               processed: Int = 1,
                               changes: Int = 1,
                               enteredWith: String? = #"{"event":"go","from":"red","to":"green"}"#,
                               log: String = #"[{"event":"go","from":"red","to":"green"}]"#) -> Data {
        let enteredWith = enteredWith.map { #""enteredWith":\#($0),"# } ?? ""
        return Data((#"{\#(enteredWith)"processedEventsCount":\#(processed),"rules":[{"event":"go","from":"red","to":"green"}],"#
            + #""state":"\#(state)","stateChangeCount":\#(changes),"transitionLog":{"elements":\#(log)}}"#).utf8)
    }

    @Test func snapshotThatAgreesWithItselfIsRead() throws {
        let saved = try JSONDecoder().decode(LightMachine.Snapshot.self, from: savedSnapshot())

        #expect(saved.state == .green)
    }

    @Test(arguments: [
        (1, 2),     // More transitions made than events processed.
        (-1, -1),   // Negative counts.
    ])
    func countsThatDoNotAddUpAreNotRead(processed: Int, changes: Int) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LightMachine.Snapshot.self, from: savedSnapshot(processed: processed, changes: changes))
        }
    }

    @Test func transitionMadeWithoutTheTransitionEnteringTheStateIsNotRead() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LightMachine.Snapshot.self, from: savedSnapshot(enteredWith: nil))
        }
    }

    @Test func lastTransitionLeadingToAnotherStateIsNotRead() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LightMachine.Snapshot.self, from: savedSnapshot(state: "amber"))
        }
    }

    @Test func logWithMoreTransitionsThanMadeIsNotRead() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LightMachine.Snapshot.self, from: savedSnapshot(
                log: #"[{"event":"go","from":"red","to":"green"},{"event":"go","from":"red","to":"green"}]"#))
        }
    }

    @Test func transitionMadeWithARuleNotAmongTheRulesIsNotRead() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LightMachine.Snapshot.self, from: savedSnapshot(
                enteredWith: #"{"event":"slow","from":"red","to":"green"}"#,
                log: #"[{"event":"slow","from":"red","to":"green"}]"#))
        }
    }
}
