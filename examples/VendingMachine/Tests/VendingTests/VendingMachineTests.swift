import MiamiStateMachine
import Testing
import Vending
import VendingModel

struct VendingMachineTests {

    /// Inserts coins, one at a time.
    private func insert(_ coins: Int..., into machine: VendingMachine) async throws {
        for cents in coins {
            _ = try await machine.process(.insertCoin(cents: cents))
        }
    }

    // MARK: - The definition

    @Test func definitionIsConsistentAndEveryStateIsReachable() throws {
        let stateMachine = try StateMachine<VendingEvent, VendingState, Void>(transitions: VendingMachine.rules.rules, initialState: .idle)

        #expect(stateMachine.transitionCount == 19)
        #expect(stateMachine.unreachableStates.isEmpty)
        #expect(stateMachine.endingStates.isEmpty, "The machine never stops for good.")
    }

    @Test func everyStateCanBreakDownAndBeRefilled() throws {
        let stateMachine = try StateMachine<VendingEvent, VendingState, Void>(transitions: VendingMachine.rules.rules, initialState: .idle)

        for state in VendingState.allCases {
            #expect(stateMachine.transition(from: state, for: .refill)?.to == state)
            if state != .outOfOrder {
                #expect(stateMachine.transition(from: state, for: .breakDown)?.to == .outOfOrder)
            }
        }
        #expect(stateMachine.events(from: .outOfOrder) == [.repair, .refill])
    }

    // MARK: - Buying

    @Test func buyingDrinkDeliversItAndReturnsTheChange() async throws {
        let machine = VendingMachine()
        try await insert(100, 100, into: machine)

        let transition = try await machine.process(.select(drink: .pepsiMax))

        #expect(transition.from == .hasCredit)
        #expect(transition.to == .drinkReady)
        let status = await machine.status()
        #expect(status.pickup == .pepsiMax)
        #expect(status.credit == 0)
        #expect(status.coinReturn == 50)
        #expect(status.stock == [.cokeZero: 5, .pepsiMax: 4, .trocadero: 5])
    }

    @Test func drinkCostingMoreThanTheCreditIsNotDelivered() async throws {
        let machine = VendingMachine()
        try await insert(100, 25, 25, into: machine)

        await #expect(throws: VendingError.notEnoughCredit(for: .trocadero, credit: 150)) {
            try await machine.process(.select(drink: .trocadero))
        }

        let status = await machine.status()
        #expect(status.state == .hasCredit)
        #expect(status.credit == 150)
        #expect(status.pickup == nil)
    }

    @Test func soldOutDrinkIsNotDelivered() async throws {
        let machine = VendingMachine()
        for _ in 1 ... VendingMachine.capacity {
            try await insert(100, into: machine)
            _ = try await machine.process(.select(drink: .cokeZero))
            _ = try await machine.process(.takeDrink)
        }
        try await insert(100, into: machine)

        await #expect(throws: VendingError.soldOut(drink: .cokeZero)) {
            try await machine.process(.select(drink: .cokeZero))
        }
        #expect(await machine.status().stock[.cokeZero] == 0)
    }

    @Test func noDrinkIsDeliveredUntilThePickupIsCleared() async throws {
        let machine = VendingMachine()
        try await insert(100, into: machine)
        _ = try await machine.process(.select(drink: .cokeZero))
        try await insert(100, into: machine)

        await #expect(throws: VendingError.notAccepted(event: .select, at: .drinkReadyWithCredit)) {
            try await machine.process(.select(drink: .cokeZero))
        }

        _ = try await machine.process(.takeDrink)
        let transition = try await machine.process(.select(drink: .cokeZero))
        #expect(transition.to == .drinkReady)
    }

    // MARK: - Coins

    @Test func cancellingReturnsTheCredit() async throws {
        let machine = VendingMachine()
        try await insert(25, 10, 5, into: machine)

        _ = try await machine.process(.cancel)

        let status = await machine.status()
        #expect(status.state == .idle)
        #expect(status.credit == 0)
        #expect(status.coinReturn == 40)
        #expect(await machine.takeCoins() == 40)
        #expect(await machine.status().coinReturn == 0)
    }

    @Test func cancellingWithoutCreditIsNotAccepted() async throws {
        let machine = VendingMachine()

        await #expect(throws: VendingError.notAccepted(event: .cancel, at: .idle)) {
            try await machine.process(.cancel)
        }
    }

    @Test func unknownCoinIsHandedStraightBack() async throws {
        let machine = VendingMachine()

        await #expect(throws: VendingError.coinNotAccepted(cents: 1)) {
            try await machine.process(.insertCoin(cents: 1))
        }

        let status = await machine.status()
        #expect(status.state == .idle)
        #expect(status.credit == 0)
        #expect(status.coinReturn == 0)
    }

    // MARK: - Breaking down

    @Test func creditIsLostWhenTheMachineBreaksDown() async throws {
        let machine = VendingMachine()
        try await insert(100, into: machine)

        _ = try await machine.process(.breakDown)

        let status = await machine.status()
        #expect(status.state == .outOfOrder)
        #expect(status.credit == 0)
        #expect(status.coinReturn == 0)
    }

    @Test func coinInsertedIntoBrokenMachineFallsToTheCoinReturn() async throws {
        let machine = VendingMachine()
        _ = try await machine.process(.breakDown)

        await #expect(throws: VendingError.notAccepted(event: .insertCoin, at: .outOfOrder)) {
            try await machine.process(.insertCoin(cents: 25))
        }
        #expect(await machine.status().coinReturn == 25)
    }

    @Test func repairClearsThePickup() async throws {
        let machine = VendingMachine()
        try await insert(100, into: machine)
        _ = try await machine.process(.select(drink: .cokeZero))
        _ = try await machine.process(.breakDown)

        _ = try await machine.process(.repair)

        let status = await machine.status()
        #expect(status.state == .idle)
        #expect(status.pickup == nil)
    }

    // MARK: - Refilling

    @Test func refillingFillsEveryDrinkAndKeepsTheState() async throws {
        let machine = VendingMachine()
        try await insert(100, 100, into: machine)
        _ = try await machine.process(.select(drink: .trocadero))
        _ = try await machine.process(.breakDown)

        let transition = try await machine.process(.refill)

        #expect(transition.from == .outOfOrder)
        #expect(transition.to == .outOfOrder)
        #expect(await machine.status().stock == [.cokeZero: 5, .pepsiMax: 5, .trocadero: 5])
    }

    // MARK: - Requests at once

    @Test func manySelectionsAtOnceDeliverOneDrink() async throws {
        let machine = VendingMachine()
        try await insert(100, into: machine)

        // Enough credit for one drink, asked for many times at once. Only one is delivered.
        let delivered = await withTaskGroup(of: Bool.self) { group in
            for _ in 1 ... 20 {
                group.addTask {
                    (try? await machine.process(.select(drink: .cokeZero))) != nil
                }
            }
            return await group.reduce(0) { count, wasDelivered in count + (wasDelivered ? 1 : 0) }
        }

        #expect(delivered == 1)
        #expect(await machine.status().stock[.cokeZero] == 4)
    }
}
