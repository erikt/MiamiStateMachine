# MiamiStateMachine
![Floreda](images/lisa_simpson_floreda.jpg)
> *Come on, shake your body, baby, do the conga<br/>
> I know you can't control yourself any longer*
> 
—Enrique Garcia

MiamiStateMachine is a simple, small and—honestly—a naive Swift finite state machine
implementation.

## Concepts

A `StateMachine` has a `state: State` (the current state). The `State` is an associated type
conforming to `Hashable`. An `enum` defining the possible states works well. (Please note,
the `state` should never be modified directly. At the moment the protocol extension's default
implementation of the `process(_:Event)` method, needs to set the new state, but a better
solution might be needed to fix this ... ) 

The transitions between states are defined by `Transition`, a value with the `from: State`, the
`event: Event` needed to do the transition and the `to: State` where the state machine ends up.

The `Event` is also an associated type conforming to `Hashable`, usually an enum.

To make the state machine process an event, the `mutating func process(_ event: Event)` is used.
If a transition is defined for the event from the current state, the state machine's 
current state will change.

Side effects when transitioning between states, can be handled by implementing any of:
```
func willChangeState(with transition: Transition<Event, State>)
func didChangeState(with transition: Transition<Event, State>)
func willNotChangeState(for event: Event)
func didNotChangeState(for event: Event)
```

## Usage

To use the state machine, make your type conform to the `StateMachine` protocol.
If you use a value type, please note the state machine mutates its `state`, producing a new value.

```
import MiamiStateMachine 
   
final class MyClass: StateMachine {

   enum MyState { 
      case s1, s2, s3
   }
    
   enum MyEvent {
      case s1ToS2, s2ToS3, s2ToS1     
   }

   fileprivate var state: MyState = .s1
   fileprivate let transitions: Set<Transition<MyEvent, MyState>> = [
      Transition(from: .s1, event: .s1ToS2, to: .s2),
      Transition(from: .s2, event: .s2ToS3, to: .s3),
      Transition(from: .s2, event: .s2ToS1, to: .s1),
   ]
}
```

To handle possible side effects related to state changes or when an event does not lead 
to a state change, implement:

```
extension MyClass {
   func willChangeState(with transition: Transition<MyEvent, MyState>) {
      switch (from: transition.from, to: transition.to) {
      case (from: .s1, to: .s2):
         print("Will change state from s1 to s2.")
      default:
         break
      }
   }
   
   func didChangeState(with transition: Transition<MyEvent, MyState>) {
      switch (from: transition.from, to: transition.to) {
      case (from: .s1, to: .s2):
         print("Did change state from s1 to s2.")
      default:
         break
      }
   }
    
   func didNotChangeState(for event: MyEvent) {
      print("Warning: \(event) did not change state from current state \(state).")
   }
}
``` 

To use this state machine:

```
var m = MyClass()
print("Current state: \(m.state)")

// SM is in s1

m.process(.s1ToS2)
print("Current state: \(m.state)")

// SM is in s2

m.process(.s2ToS3)
print("Current state: \(m.state)")

// SM is in s3

m.process(.s1ToS2)
print("Current state: \(m.state)")

// SM is still in s3. Event had no effect.
```

## Future improvements

The obvious needed improvement is the modifiable state machine current `state`. This 
should really only be changed internally and not be directly modifiable. Only processing
events should change the state. But, you know, Swift generics and type theory in 
general ... sigh ... how does it all work?! I have no idea ...

Thread-safety. 

A `StateMachineDelegate` protocol, defining the side effect methods, would be preferable to
the current architecture.

As usual, more extensive tests could be written and coverage could be improved.

## What's with the name?

Look, naming is hard, ok? If nothing else, we all know *the rhythm is gonna get you*. 
Just be happy I didn't name it `RageAgainstTheStateMachine`.

## Author
Copyright &copy; 2022 Erik Tjernlund <erik@tjernlund.net>
