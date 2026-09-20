import Testing
import MiamiStateMachine

struct StateMachineTests {

    // MARK: - Entered with

    @Test func enteredWithIsNilUntilFirstTransition() async throws {
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions, initialState: .cart))
        #expect(await stateMachine.enteredWith == nil)

        // Rejected, as there is nothing to ship in the cart.
        await stateMachine.process(.ship)
        #expect(await stateMachine.enteredWith == nil)
    }

    @Test func enteredWithIsLastTransitionMade() async throws {
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions, initialState: .cart))

        await stateMachine.process(.checkOut)
        #expect(await stateMachine.enteredWith == StateTransition(from: .cart, event: .checkOut, to: .checkout))

        await stateMachine.process(.pay)
        #expect(await stateMachine.enteredWith == StateTransition(from: .checkout, event: .pay, to: .paid))

        // A rejected event does not change how the state was entered.
        await stateMachine.process(.checkOut)
        #expect(await stateMachine.enteredWith == StateTransition(from: .checkout, event: .pay, to: .paid))
    }

    @Test(arguments: [0, 1, nil] as [UInt?])
    func enteredWithDoesNotDependOnTheLogCapacity(logCapacity: UInt?) async throws {
        let stateMachine = try #require(StateMachine(transitions: OrderFixture.transitions,
                                                     initialState: .cart,
                                                     logCapacity: logCapacity))
        await stateMachine.process(.checkOut)
        await stateMachine.process(.pay)

        #expect(await stateMachine.enteredWith == StateTransition(from: .checkout, event: .pay, to: .paid))
    }
}
