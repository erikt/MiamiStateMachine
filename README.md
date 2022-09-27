# MiamiStateMachine
![Floreda](images/lisa_simpson_floreda.jpg)
> *Come on, shake your body, baby, do the conga<br/>
> I know you can't control yourself any longer*
> 
—Enrique Garcia

MiamiStateMachine is a small finite state machine implementation written in Swift.
It uses a Swift actor to protect the current state and the definition of the state machine
from unsafe modification.

## Motivation

I needed a state machine I could trust to consider things like concurrent use. 
The only available alternative in the macOS, iOS or iPadOS platform frameworks, 
is `GKStateMachine` in GameplayKit. This is an Objective-C based state machine,
seemingly not updated since its introduction. It is unclear to me if `GKStateMachine`
does anything to try to be thread-safe or if this is up to the developer using
the framework.

## Concepts

A `StateMachine` has a `state: State` (the current state). The `State` is an associated type
conforming to `Hashable`. An `enum` defining the possible states works well. 

The transitions between states are defined by `Transition`, a value with the `from: State`, the
`event: Event` needed to do the transition and the `to: State` where the state machine ends up.

The `Event` is also an associated type conforming to `Hashable`, usually an enum.

To make the state machine process an event, the `process(:)` is used. If a transition is 
defined for the event from the current state, the state machine's current state will change.

Side-effects when transitioning between states, can be handled by implementing either the
`didChangeState` or the `didNotChangeState` method.

```
func didChangeState(with: Transition<Event, State>)
func didNotChangeState(from: State, for: Event)
```

## Usage

TODO: Rewrite usage documentation after the major rewrite of the state machine code.

~~To use the state machine, make your type conform to the `StateMachineDelegate` protocol.
Define the state and event type (an enum works well for example), define the 
transitions in the state machine and lastly, set the `stateMachine` property with
the initial state and the transitions.~~

![State Machine Example](images/state-machine-example.png)

~~To handle possible side-effects related to state changes or when an event does not lead 
to a state change, implement:~~

```
extension MyStateMachine {
   func didChangeState(with transition: Transition<MyEvent, MyState>) {
      switch (from: transition.from, to: transition.to) {
      case (from: .s1, to: .s2):
         print("Did change state from s1 to s2 by event \(transition.event).")
      default:
         break
      }
   }
    
   func didNotChangeState(from state: MyState, for event: MyEvent) {
      print("Warning: \(event) did not change state from state \(state).")
   }
}
``` 

~~To use this state machine (in an async context):~~

```
var m = MyStateMachine()

// SM is in s1

await m.process(.e1)

// SM is in s2

await m.process(.e2)

// SM is in s3

await m.process(.e3)

// SM is still in s3. Event e3 had no effect.

await m.atEndingState

// true
// The s3 state has no transitions defined for any event.
```

## What's with the name?

Look, naming is hard, ok? If nothing else, we all know *the rhythm is gonna get you*. 
Just be happy I didn't name it `RageAgainstTheStateMachine`.

## Improvements

~~Speaking of naming, I do not like the protocol name `StateMachineDelegate`. It is not a delegate
in the traditional Cocoa sense of the word. It is actually a state machine trait and should be 
named *StateMachine*, but the actor protecting the current state and state machine definition
is `StateMachine`. I have been going back and forth regarding these names and they could 
definitely be improved.~~

Suggestions and or PRs welcome, but remember: *kindness before code*. 

## Author
Copyright &copy; 2022 Erik Tjernlund <erik@tjernlund.net>
