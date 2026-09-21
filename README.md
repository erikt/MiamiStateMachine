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

A `StateMachine` has a `state: State` (the current state). The `State` is a type
conforming to `Hashable` and `Sendable`. An `enum` defining the possible states works well. 

The transitions between states are defined by `StateTransition`, a value with the `from: State`, the
`event: Event` needed to do the transition and the `to: State` where the state machine ends up.

The `Event` is also a type conforming to `Hashable & Sendable`, usually an enum.

To make the state machine process an event, the `process(:)` is used. If a transition is 
defined for the event from the current state, the state machine's current state will change.

## Usage

Start by defining the possible states and events. Enumerations works well for this:

```
enum MyState {
    case s1, s2, s3
}

enum MyEvent {
    case e1, e2, e3
}
```

The state machine is defined by the transitions it can do:

```
typealias MyTransition = StateTransition<MyEvent, MyState>

let transitions: Set<MyTransition> = [
    StateTransition(from: .s1, event: .e1, to: .s2),
    StateTransition(from: .s2, event: .e2, to: .s3),
    StateTransition(from: .s1, event: .e3, to: .s3),
]
```

The state machine can now be created with the transitions:

```
let stateMachine = try StateMachine(transitions: transitions, initialState: .s1)
```

![State Machine Example](images/state-machine-example.png)

Creating the state machine throws an error if the transitions define an inconsistent state
machine. A consistent state machine is one where an event at a state always leads to the same
transition. The error is a `DefinitionError`, and its `conflictingTransitions` tells which
transitions lead from the same state, for the same event, to different states:

```
do {
    let stateMachine = try StateMachine(transitions: transitions, initialState: .s1)
} catch {
    print(error.conflictingTransitions)
}
```

Now the state machine can process events. Processing events needs to be done in
an asynchronous context:

```
Task {
  // Initial state is s1
    
  await stateMachine.process(.e1)

  // State is s2
    
  await stateMachine.process(.e2)

  // State is s3

  await stateMachine.process(.e3)
    
  // State is still s3. Event e3 had no effect.

  await stateMachine.isAtEndingState
    
  // True as s3 state has no transitions defined for any event.
}
```

Processing an event returns the transition made, or `nil` if the event was rejected. This tells what the
event led to, also when other tasks are processing events at the same time:

```
if let transition = await stateMachine.process(.e1) {
    print("Entered \(transition.to)")
} else {
    print("The event was rejected")
}
```

## Reacting to state changes

To react to the transitions made by the state machine, ask it for a stream of transitions:

```
let transitions = await stateMachine.transitionStream()

Task {
    for await transition in transitions {
        print("Entered \(transition.to) by \(transition.event)")
    }

    // The state machine has reached an ending state, or is deallocated.
}
```

There is also `rejectedEventStream()`, to be able to know when processed events did __not__ lead to a transition. Its
elements are `RejectedEvent` values, with the rejected `event` and the `state` the state machine was at.

Some things to know about the streams:

- Every call creates a new stream. Several consumers can listen at the same time, and all of them get every element.
- A stream delivers what happens after it was created. Create the stream before processing the events of interest, as
  above. A stream created inside a new task may miss events, as the task can start running after they were processed.
- A stream of transitions finishes when the state machine reaches an ending state. A stream of rejected events does not,
  as events are rejected at an ending state too. Both finish when the state machine is deallocated.
- Cancelling the task of a consumer, or letting go of a stream, ends only that stream. Ask for a new stream to start
  listening again.
- A stream keeps its elements until they are consumed, without any limit. If only the latest are of interest, pass a
  buffering policy: `transitionStream(bufferingPolicy: .bufferingNewest(1))`.
- Use the transition received to know the state entered, and not `state`. The state machine may have moved on.

The `AsyncStream` based solution is a sort of workaround while waiting for Swift to improve observation of values in an actor.

## The transition log

The state machine keeps a log of the transitions made. The log is a collection, from the oldest transition to the newest:

```
let log = await stateMachine.transitionLog

for transition in log {
    print(transition)
}

let latest = log.last
```

The log keeps every transition by default. To only keep the latest, give the log a capacity when creating the state
machine: `StateMachine(transitions: transitions, initialState: .s1, logCapacity: 10)`.

## Finding the shortest path between states

The state machine can tell how to get from one state to another with the fewest events:

```
let path = stateMachine.shortestPath(from: .s1, to: .s3)

// [s1 --(e3)--> s3]
```

The path is the list of transitions to make, in order. For the state machine above, the shortest path from `s1` to `s3`
is the single transition for the event `e3`, and not the two transitions for `e1` and `e2`. Processing the event of each
transition, in order, takes a state machine that is in the first state of the path to the last one:

```
for transition in path ?? [] {
    await stateMachine.process(transition.event)
}
```

If there is no way to get to the state, the path is `nil`. The path from a state to the same state is empty. If there is
more than one shortest path, one of them is returned.

The shortest path between two states is part of the definition of the state machine and does not depend on the current
state, so there is no need for an asynchronous context. To get the shortest path from the current state, use
`shortestPath(to:)`, which must be awaited:

```
let pathFromCurrent = await stateMachine.shortestPath(to: .s3)
```

## Checking the definition

The state machine can answer questions about its definition as a whole. They are made for finding mistakes in a
definition, and fit well in a unit test:

```
// States the state machine will never be at, as nothing leads to them from the initial state.
stateMachine.unreachableStates

// States from where the state machine can never get to an ending state.
stateMachine.statesWithoutPathToEndingState

// If there is a way from a state back to the same state, so that the state machine can go on forever.
stateMachine.hasCycle
```

For the state machine above, the first two are empty and the last is `false`. An unreachable state is often a forgotten
transition, or a transition leading to the wrong state. A state machine without ending states, meant to go on forever,
has all its states without a path to an ending state.

There are also `states`, `endingStates` and `reachableStates(from:)`. A state is always reachable from itself:

```
stateMachine.reachableStates(from: .s2)

// [s2, s3]
```

All of these are part of the definition of the state machine, so there is no need for an asynchronous context. For the
states that can still be reached from the current state, use `reachableStatesFromCurrent`, which must be awaited.

## What's with the name?

Look, naming is hard, ok? If nothing else, we all know *the rhythm is gonna get you*. 
Just be happy I didn't name it `RageAgainstTheStateMachine`.

## Improvements

Suggestions, issues and or PRs are more than welcome, but remember: *kindness before code*. 

## Author
Copyright &copy; 2022 Erik Tjernlund <erik@tjernlund.net>
