import XCTest
@testable import MiamiStateMachine

final class MiamiStateMachineTests: XCTestCase {
    func testStartState() async {
        let m = MyStateMachine()
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
        let m = MyStateMachine()
        let st1 = await m.state
        XCTAssertEqual(st1, .s1, "State machine should start at s1.")
        await m.process(.s3ToEnd)
        let st2 = await m.state
        XCTAssertEqual(st2, .s1, "State machine should not change state after processing s3ToEnd event.")
        var eventsProcessed = await m.stateMachine.processedEventsCount
        var stateChanges = await m.stateMachine.stateChangeCount
        XCTAssertEqual(eventsProcessed, 1, "Processed events should be 1")
        XCTAssertEqual(stateChanges, 0, "State changes should be 0")
        
        await m.process(.s1ToS2)
        let st3 = await m.state
        XCTAssertEqual(st3, .s2, "State machine should have transitioned to s2 after processing s1ToS2 event.")
        await m.process(.s2ToS3)
        await m.process(.s3ToEnd)
        let st4 = await m.state
        let atEnd = await m.atEndingState
        XCTAssertEqual(st4, .end, "State machine should be at end state.")
        XCTAssertTrue(atEnd, "State machine should have reached an end state.")

        eventsProcessed = await m.stateMachine.processedEventsCount
        stateChanges = await m.stateMachine.stateChangeCount
        let rejected = await m.stateMachine.rejectedEventsCount
        XCTAssertEqual(eventsProcessed, 4, "Events processed should be 4")
        XCTAssertEqual(stateChanges, 3, "State changes should be 3")
        XCTAssertEqual(rejected, 1, "Rejected events should be 1")
    }
    
    func testTransitionLog() async {
        let m = MyStateMachine()
        await m.process(.s1ToS2)
        await m.process(.s2ToS3)
        await m.process(.s3ToEnd)
        
        var transitions = await m.stateMachine.transitionLog
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
    
    func testIllegalStateMachine() async {
        let illegalM = MyBrokenStateMachine()
        let broken = (illegalM == nil)
        XCTAssertTrue(broken, "Should not be possible to create an inconsistent state machine.")
    }
    
    func testTransitionLogCapacity() async {
        let m = MyDemoStateMachine()
        
        await m.process(.e4)
        var log = await m.stateMachine.transitionLog
        let expectedT1 = Transition(from: MyDemoStateMachine.MyState.s1,
                                   event: MyDemoStateMachine.MyEvent.e4,
                                   to: MyDemoStateMachine.MyState.s1)
        XCTAssertEqual(log.peek, log.peekOldest, "Last log entry and oldest log entry should be the same")
        XCTAssertEqual(log.count, 1, "Number of log entries should be 1")
        XCTAssertEqual(log.peek, expectedT1, "Last log entry should be from s1")
        
        await m.process(.e4)
        log = await m.stateMachine.transitionLog
        XCTAssertEqual(log.count, 2, "There should be 2 log entries")
        
        await m.process(.e4)
        log = await m.stateMachine.transitionLog
        XCTAssertEqual(log.count, 3, "There should be 3 log entries")

        await m.process(.e4)
        log = await m.stateMachine.transitionLog
        XCTAssertEqual(log.count, 4, "There should be 4 log entries")

        await m.process(.e1)
        log = await m.stateMachine.transitionLog
        XCTAssertEqual(log.count, 5, "There should be 5 log entries")

        await m.process(.e2)
        log = await m.stateMachine.transitionLog
        XCTAssertEqual(log.count, 5, "There should be 5 log entries, not \(log.count)")

        let expOld = Transition(from: MyDemoStateMachine.MyState.s1,
                                event: MyDemoStateMachine.MyEvent.e4,
                                to: MyDemoStateMachine.MyState.s1)
        let expLast = Transition(from: MyDemoStateMachine.MyState.s2,
                                event: MyDemoStateMachine.MyEvent.e2,
                                to: MyDemoStateMachine.MyState.s3)
        XCTAssertEqual(log.peekOldest, expOld, "Oldest entry is not expected")
        XCTAssertEqual(log.peek, expLast, "Last entry is not expected")        
    }
}
