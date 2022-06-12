import XCTest
@testable import MiamiStateMachine

fileprivate final class MyClass: StateMachine {

    enum MyState {
        case s1
        case s2
        case s3
        case end
    }
    
    enum MyEvent {
        case s1ToS2
        case s2ToS3
        case s1ToS3
        case s3ToEnd
    }
    
    fileprivate var state: MyState = .s1
    fileprivate let transitions: Set<Transition<MyEvent, MyState>> = [
        Transition(from: .s1, event: .s1ToS2, to: .s2),
        Transition(from: .s1, event: .s1ToS3, to: .s3),
        Transition(from: .s2, event: .s2ToS3, to: .s3),
        Transition(from: .s3, event: .s3ToEnd, to: .end)
    ]
}

final class MiamiStateMachineTests: XCTestCase {
    func testStartState() throws {
        let m = MyClass()
        XCTAssertEqual(m.hasReachedEnd, false, "State machine should not have reached an end state.")
        XCTAssertEqual(m.transitions.count, 4, "State machine should have 5 defined transitions.")
        XCTAssertEqual(m.canTransition(to: .end), false, "No possible transition to end state.")
        XCTAssertEqual(m.canTransition(to: .s2), true, "Should be possible to transition to s2 state from s1.")
        XCTAssertEqual(m.transitions(to: .s2).count, 1, "Should be 1 transition from current state to s2.")
        XCTAssertEqual(m.transitions(to: .end).count, 0, "Should not exist any transition to end state from s1.")
    }
    
    func testProcessEvent() throws {
        var m = MyClass()
        XCTAssertEqual(m.state, .s1, "State machine should start at s1.")
        m.process(.s3ToEnd)
        XCTAssertEqual(m.state, .s1, "State machine should not change state after processing s3ToEnd event.")
        m.process(.s1ToS2)
        XCTAssertEqual(m.state, .s2, "State machine should have transitioned to s2 after processing s1ToS2 event.")
        m.process(.s2ToS3)
        m.process(.s3ToEnd)
        XCTAssertEqual(m.state, .end, "State machine should be at end state.")
        XCTAssertTrue(m.hasReachedEnd, "State machine should have reached an end state.")
    }
}
