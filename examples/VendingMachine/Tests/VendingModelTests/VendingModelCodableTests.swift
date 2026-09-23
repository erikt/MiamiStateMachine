import Foundation
import MiamiStateMachine
import Testing
import VendingModel

/// The JSON of the API, spelled out. A client reads what the server writes,
/// so the format must not change by accident, as by renaming a property.
struct VendingModelCodableTests {

    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private let status = VendingStatus(state: .drinkReady,
                                       credit: 0,
                                       coinReturn: 50,
                                       pickup: .pepsiMax,
                                       stock: [.cokeZero: 5, .pepsiMax: 4, .trocadero: 5],
                                       acceptedEvents: [.insertCoin, .takeDrink, .breakDown, .refill])

    private let statusJSON = """
        {"acceptedEvents":["insertCoin","takeDrink","breakDown","refill"],"coinReturn":50,"credit":0,\
        "pickup":"pepsiMax","state":"drinkReady","stock":{"cokeZero":5,"pepsiMax":4,"trocadero":5}}
        """

    // MARK: - Events

    @Test(arguments: [
        (VendingEvent.insertCoin(cents: 100), #"{"insertCoin":{"cents":100}}"#),
        (VendingEvent.select(drink: .trocadero), #"{"select":{"drink":"trocadero"}}"#),
        (VendingEvent.takeDrink, #"{"takeDrink":{}}"#),
        (VendingEvent.cancel, #"{"cancel":{}}"#),
        (VendingEvent.breakDown, #"{"breakDown":{}}"#),
        (VendingEvent.repair, #"{"repair":{}}"#),
        (VendingEvent.refill, #"{"refill":{}}"#),
    ])
    func eventIsWrittenAndRead(event: VendingEvent, json: String) throws {
        #expect(try encode(event) == json)
        #expect(try decode(VendingEvent.self, from: json) == event)
    }

    @Test func triggersAreWrittenAsTheirNames() throws {
        let triggers = VendingEvent.EventTrigger.allCases
        let json = #"["insertCoin","select","takeDrink","cancel","breakDown","repair","refill"]"#

        #expect(try encode(triggers) == json)
        #expect(try decode([VendingEvent.EventTrigger].self, from: json) == triggers)
    }

    @Test func unknownTriggerIsNotRead() {
        #expect(throws: DecodingError.self) {
            try decode(VendingEvent.EventTrigger.self, from: #""explode""#)
        }
    }

    // MARK: - Answers

    @Test func statusIsWrittenAndRead() throws {
        #expect(try encode(status) == statusJSON)
        #expect(try decode(VendingStatus.self, from: statusJSON) == status)
    }

    @Test func statusWithEmptyPickupLeavesItOut() throws {
        let idle = VendingStatus(state: .idle, credit: 0, coinReturn: 0, pickup: nil,
                                 stock: [:], acceptedEvents: [.insertCoin])
        let json = #"{"acceptedEvents":["insertCoin"],"coinReturn":0,"credit":0,"state":"idle","stock":{}}"#

        #expect(try encode(idle) == json)
        #expect(try decode(VendingStatus.self, from: json) == idle)
    }

    @Test func productIsWrittenAndRead() throws {
        let product = Product(.pepsiMax, stock: 4)
        let json = #"{"drink":"pepsiMax","name":"Pepsi Max","price":150,"stock":4}"#

        #expect(try encode(product) == json)
        #expect(try decode(Product.self, from: json) == product)
    }

    @Test func transitionResponseIsWrittenAndRead() throws {
        let transition = TransitionEvent<VendingEvent, VendingState>(from: .hasCredit, event: .select(drink: .pepsiMax), to: .drinkReady)
        let response = TransitionResponse(transition: transition, machine: status)
        let json = """
            {"machine":\(statusJSON),\
            "transition":{"event":{"select":{"drink":"pepsiMax"}},"from":"hasCredit","to":"drinkReady"}}
            """

        #expect(try encode(response) == json)
        #expect(try decode(TransitionResponse.self, from: json) == response)
    }

    @Test func rejectionResponseIsWrittenAndRead() throws {
        let response = RejectionResponse(error: .notAccepted(event: .select, at: .drinkReady), machine: status)
        let json = """
            {"error":{"notAccepted":{"at":"drinkReady","event":"select"}},"machine":\(statusJSON),\
            "reason":"The event select is not accepted when the machine is at drinkReady."}
            """

        #expect(try encode(response) == json)
        #expect(try decode(RejectionResponse.self, from: json) == response)
    }

    @Test(arguments: [
        (VendingError.notAccepted(event: .cancel, at: .idle), #"{"notAccepted":{"at":"idle","event":"cancel"}}"#),
        (VendingError.coinNotAccepted(cents: 1), #"{"coinNotAccepted":{"cents":1}}"#),
        (VendingError.notEnoughCredit(for: .trocadero, credit: 150), #"{"notEnoughCredit":{"credit":150,"for":"trocadero"}}"#),
        (VendingError.soldOut(drink: .cokeZero), #"{"soldOut":{"drink":"cokeZero"}}"#),
    ])
    func errorIsWrittenAndRead(error: VendingError, json: String) throws {
        #expect(try encode(error) == json)
        #expect(try decode(VendingError.self, from: json) == error)
    }

    @Test func coinsResponseIsWrittenAndRead() throws {
        let json = #"{"cents":50}"#

        #expect(try encode(CoinsResponse(cents: 50)) == json)
        #expect(try decode(CoinsResponse.self, from: json) == CoinsResponse(cents: 50))
    }
}
