import XCTest
@testable import MiamiStateMachine

fileprivate final class MyClass: StateMachineDelegate {
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
    
    static let transitions: Set<Transition<MyEvent, MyState>> = [
        Transition(from: .s1, event: .s1ToS2, to: .s2),
        Transition(from: .s1, event: .s1ToS3, to: .s3),
        Transition(from: .s2, event: .s2ToS3, to: .s3),
        Transition(from: .s3, event: .s3ToEnd, to: .end)
    ]

    let stateMachine: StateMachine<MyEvent, MyState> = StateMachine(initialState: .s1, transitions: transitions)
    
    func didChangeState(with transition: Transition<MyEvent, MyState>) {
       switch (from: transition.from, to: transition.to) {
       case (from: .s1, to: .s2):
          print("Did change state from s1 to s2.")
       default:
          break
       }
    }
}

final class MiamiStateMachineTests: XCTestCase {
    func testStartState() async {
        let m = MyClass()
        let atEnd = await m.atEndingState
        let toEnd = await m.canTransition(to: .end)
        let toS2 = await m.canTransition(to: .s2)
        let numToS2 = await m.transitions(to: .s2).count
        let numToEnd = await m.transitions(to: .end).count
        let numTransitions = await m.transitions.count
        
        XCTAssertEqual(atEnd, false, "State machine should not have reached an end state.")
        XCTAssertEqual(numTransitions, 4, "State machine should have 5 defined transitions.")
        XCTAssertEqual(toEnd, false, "No possible transition to end state.")
        XCTAssertEqual(toS2, true, "Should be possible to transition to s2 state from s1.")
        XCTAssertEqual(numToS2, 1, "Should be 1 transition from current state to s2.")
        XCTAssertEqual(numToEnd, 0, "Should not exist any transition to end state from s1.")
    }
    
    func testProcessEvent() async {
        let m = MyClass()
        let st1 = await m.state
        XCTAssertEqual(st1, .s1, "State machine should start at s1.")
        await m.process(.s3ToEnd)
        let st2 = await m.state
        XCTAssertEqual(st2, .s1, "State machine should not change state after processing s3ToEnd event.")
        await m.process(.s1ToS2)
        let st3 = await m.state
        XCTAssertEqual(st3, .s2, "State machine should have transitioned to s2 after processing s1ToS2 event.")
        await m.process(.s2ToS3)
        await m.process(.s3ToEnd)
        let st4 = await m.state
        let atEnd = await m.atEndingState
        XCTAssertEqual(st4, .end, "State machine should be at end state.")
        XCTAssertTrue(atEnd, "State machine should have reached an end state.")
    }
    
    func testTransitionLog() async {
        let m = MyClass()
        await m.process(.s1ToS2)
        await m.process(.s2ToS3)
        await m.process(.s3ToEnd)
        
        var transitions = await m.stateMachine.commitStack
        let t1 = transitions.pop()!
        XCTAssertEqual(t1.from, .s3, "Transition should be from S3")
        XCTAssertEqual(t1.to, .end, "Transition should be to end")
        XCTAssertEqual(t1.event, .s3ToEnd, "Transition event should be s3ToEnd")
        
        let t2 = transitions.pop()!
        XCTAssertEqual(t2.from, .s2, "Transition should be from S2")
        XCTAssertEqual(t2.to, .s3, "Transition should be to S3")
        XCTAssertEqual(t2.event, .s2ToS3, "Transition event should be s2ToS3")

        let t3 = transitions.pop()!
        XCTAssertEqual(t3.from, .s1, "Transition should be from S1")
        XCTAssertEqual(t3.to, .s2, "Transition should be to S2")
        XCTAssertEqual(t3.event, .s1ToS2, "Transition event should be s1ToS2")

        XCTAssertEqual(transitions.pop(), nil, "There should be no more commited transitions")
    }
}
