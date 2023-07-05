import XCTest
@testable import MiamiStateMachine
@testable import Graph

final class MiamiStateMachineTests: XCTestCase {
    func testStartState() async {
        let sm1 = StateMachine(transitions: t1, initialState: .s1)!
        let atEnd = await sm1.atEndingState
        let toEnd = await sm1.canTransition(to: .end)
        let toS2 = await sm1.canTransition(to: .s2)
        let numToS2 = await sm1.transitionsFromCurrent(to: .s2).count
        let numToEnd = await sm1.transitionsFromCurrent(to: .end).count
        let numTransitions = sm1.numOfTransitions
        
        XCTAssertEqual(atEnd, false, "State machine should not have reached an end state.")
        XCTAssertEqual(numTransitions, 4, "State machine definition should have 4 defined transitions.")
        XCTAssertEqual(toEnd, false, "No possible transition to end state.")
        XCTAssertEqual(toS2, true, "Should be possible to transition to s2 state from s1.")
        XCTAssertEqual(numToS2, 1, "Should be 1 transition from current state to s2.")
        XCTAssertEqual(numToEnd, 0, "Should not exist any transition to end state from s1.")
        
        let g = AdjacencyList<S1>.createFrom(transitions: t1)
        print(g)
        let d = Dijkstra<S1>(graph: g)
        let start = g.vertices.first(where: { $0.data == .s1 })!
        let end = g.vertices.first(where: { $0.data == .end })!
        let ps = d.getAllShortestPath(from: start)
        print(ps)
        
        print("Shortest path from \(start) to \(end):")
        for e in ps[end]! {
            let transition = sm1.transitions(from: e.source.data, to: e.destination.data).first!
            print(transition)
        }
    }
    
    func testProcessEvent() async {
        let sm1 = StateMachine(transitions: t1, initialState: .s1)!
        let st1 = await sm1.state
        XCTAssertEqual(st1, .s1, "State machine should start at s1.")
        await sm1.process(.s3ToEnd)
        let st2 = await sm1.state
        XCTAssertEqual(st2, .s1, "State machine should not change state after processing s3ToEnd event.")
        var eventsProcessed = await sm1.processedEventsCount
        var stateChanges = await sm1.stateChangeCount
        XCTAssertEqual(eventsProcessed, 1, "Processed events should be 1")
        XCTAssertEqual(stateChanges, 0, "State changes should be 0")
        
        await sm1.process(.s1ToS2)
        let st3 = await sm1.state
        XCTAssertEqual(st3, .s2, "State machine should have transitioned to s2 after processing s1ToS2 event.")
        await sm1.process(.s2ToS3)
        await sm1.process(.s3ToEnd)
        let st4 = await sm1.state
        let atEnd = await sm1.atEndingState
        XCTAssertEqual(st4, .end, "State machine should be at end state.")
        XCTAssertTrue(atEnd, "State machine should have reached an end state.")

        eventsProcessed = await sm1.processedEventsCount
        stateChanges = await sm1.stateChangeCount
        let rejected = await sm1.rejectedEventsCount
        XCTAssertEqual(eventsProcessed, 4, "Events processed should be 4")
        XCTAssertEqual(stateChanges, 3, "State changes should be 3")
        XCTAssertEqual(rejected, 1, "Rejected events should be 1")
    }
    
    func testTransitionLog() async {
        let sm1 = StateMachine(transitions: t1, initialState: .s1)!
        await sm1.process(.s1ToS2)
        await sm1.process(.s2ToS3)
        await sm1.process(.s3ToEnd)
        
        var transitions = await sm1.transitionLog
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
    
    func testIllegalStateMachineDefinition() {
        let illegalSm = StateMachine(transitions: illegalT, initialState: .s1)
        let broken = (illegalSm == nil)
        XCTAssertTrue(broken, "Should not be possible to create an inconsistent state machine definition.")
    }

    func testTransitionLogCapacity() async {
        let demoSm = StateMachine(transitions: transitions, initialState: .s1)!
        await demoSm.process(.e4)
        var log = await demoSm.transitionLog
        let expectedT1: MyTransition = Transition(from: .s1, event: .e4, to: .s1)
        XCTAssertEqual(log.peek, log.peekOldest, "Last log entry and oldest log entry should be the same")
        XCTAssertEqual(log.count, 1, "Number of log entries should be 1")
        XCTAssertEqual(log.peek, expectedT1, "Last log entry should be from s1")
        
        await demoSm.process(.e4)
        log = await demoSm.transitionLog
        XCTAssertEqual(log.count, 2, "There should be 2 log entries, not \(log.count)")
        
        await demoSm.process(.e4)
        log = await demoSm.transitionLog
        XCTAssertEqual(log.count, 3, "There should be 3 log entries, not \(log.count)")

        await demoSm.process(.e4)
        log = await demoSm.transitionLog
        XCTAssertEqual(log.count, 4, "There should be 4 log entries, not \(log.count)")

        await demoSm.process(.e1)
        log = await demoSm.transitionLog
        XCTAssertEqual(log.count, 5, "There should be 5 log entries, not \(log.count)")

        await demoSm.process(.e2)
        log = await demoSm.transitionLog
        XCTAssertEqual(log.count, 6, "There should be 6 log entries, not \(log.count)")

        let expOld: MyTransition = Transition(from: .s1, event: .e4, to: .s1)
        let expLast: MyTransition = Transition(from: .s2, event: .e2, to: .s3)
        XCTAssertEqual(log.peekOldest, expOld, "Oldest entry is not expected")
        XCTAssertEqual(log.peek, expLast, "Last entry is not expected")
    }
}

// Global test state machine definitions for testing.

enum S1 {
    case s1, s2, s3, end
}

enum E1 {
    case s1ToS2, s2ToS3, s1ToS3, s3ToEnd
}

let t1: Set<Transition<E1, S1>> = [
    Transition(from: .s1, event: .s1ToS2, to: .s2),
    Transition(from: .s1, event: .s1ToS3, to: .s3),
    Transition(from: .s2, event: .s2ToS3, to: .s3),
    Transition(from: .s3, event: .s3ToEnd, to: .end)
]

// --

enum S2 {
    case s1, s2, s3
}

enum E2 {
    case e1, e2, e3
}

let illegalT: Set<Transition<E2, S2>> = [
    Transition(from: .s1, event: .e1, to: .s2),
    Transition(from: .s2, event: .e2, to: .s3),
    Transition(from: .s1, event: .e3, to: .s3),
    Transition(from: .s1, event: .e3, to: .s2)
]

// --

enum MyState {
    case s1, s2, s3
}

enum MyEvent {
    case e1, e2, e3, e4
}

typealias MyTransition = Transition<MyEvent, MyState>

let transitions: Set<MyTransition> = [
    Transition(from: .s1, event: .e1, to: .s2),
    Transition(from: .s2, event: .e2, to: .s3),
    Transition(from: .s1, event: .e3, to: .s3),
    Transition(from: .s1, event: .e4, to: .s1)
]
