import Foundation
@testable import MiamiStateMachine

final class MyClass: StateMachineDelegate {
    enum MyState {
        case s1, s2, s3, end
    }
    
    enum MyEvent {
        case s1ToS2, s2ToS3, s1ToS3, s3ToEnd
    }
    
    static let transitions: Set<Transition<MyEvent, MyState>> = [
        Transition(from: .s1, event: .s1ToS2, to: .s2),
        Transition(from: .s1, event: .s1ToS3, to: .s3),
        Transition(from: .s2, event: .s2ToS3, to: .s3),
        Transition(from: .s3, event: .s3ToEnd, to: .end)
    ]

    let stateMachine: StateMachine<MyEvent, MyState> = StateMachine(initialState: .s1, transitions: transitions)!
}

/// A demo state machine with an inconsistent state machine definition.
final class MyBrokenClass: StateMachineDelegate {
    enum MyState {
        case s1, s2, s3
    }
    
    enum MyEvent {
        case e1, e2, e3
    }
    
    static let illegalTransitions: Set<Transition<MyEvent, MyState>> = [
        Transition(from: .s1, event: .e1, to: .s2),
        Transition(from: .s2, event: .e2, to: .s3),
        Transition(from: .s1, event: .e3, to: .s3),
        Transition(from: .s1, event: .e3, to: .s2)
    ]
    
    let stateMachine: StateMachine<MyEvent, MyState>
    
    init?() {
        if let sm = StateMachine(initialState: .s1, transitions: MyBrokenClass.illegalTransitions) {
            self.stateMachine = sm
        } else {
            return nil
        }
    }
}

/// A demo state machine with the same states and events as the documentation.
final class MyDemoClass: StateMachineDelegate {
    
    typealias MyTransition = Transition<MyEvent, MyState>
    
    enum MyState {
        case s1, s2, s3
    }
    
    enum MyEvent {
        case e1, e2, e3
    }
    
    static let transitions: Set<MyTransition> = [
        Transition(from: .s1, event: .e1, to: .s2),
        Transition(from: .s2, event: .e2, to: .s3),
        Transition(from: .s1, event: .e3, to: .s3)
    ]
    
    let stateMachine: StateMachine<MyEvent, MyState>
    
    init() {
        if let sm = StateMachine(initialState: .s1, transitions: MyDemoClass.transitions) {
            self.stateMachine = sm
        } else {
            self.stateMachine = StateMachine(initialState: .s1, transitions: Set<MyTransition>())!
        }
    }
}

