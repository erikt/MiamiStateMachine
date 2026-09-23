# VendingMachine

An example of using MiamiStateMachine: a vending machine with a server and a command line client.

The machine sells three drinks, Coke Zero ($1.00), Pepsi Max ($1.50) and Trocadero ($2.00), and holds five of each.
It takes coins of 5, 10, 25 and 100 cents. It has a button for each drink, a cancel button, a coin return and a pickup.
A drink can only be bought when the pickup is empty. The machine can break down at any time, and is then repaired by a technician,
who also clears the pickup. The credit of a broken machine is lost. The machine can be refilled at any time.

The state machine decides which events are accepted. The amounts are kept next to it by the `VendingMachine` actor:
the credit, the coin return and the stock. The actor checks them before an event is processed.

## The package

The package depends on MiamiStateMachine in the folder two levels up, so it always uses the code of this repository.

| Target | What it is |
|---|---|
| `VendingModel` | The types the server and its clients share: the drinks, states, events and errors, and the answers of the API. All are `Codable`. |
| `Vending` | The rules of the state machine, and the `VendingMachine` actor. |
| `VendingServer` | The server, the product `vending-server`, built on [Hummingbird](https://github.com/hummingbird-project/hummingbird). |
| `VendingClient` | The command line client, the product `vend`, built on [Swift Argument Parser](https://github.com/apple/swift-argument-parser). |

A client only needs `VendingModel`, to read the JSON of the server into the same Swift types the server wrote it from.

## Building

It needs Swift 6.3 or later and macOS 15 or later. All commands are run in this folder.

```bash
swift build
swift test
```

`swift build -c release` builds the programs with optimizations, into `.build/release`.

## Starting the server

```bash
swift run vending-server
```

The server listens on `127.0.0.1`, port `8080`, until it is stopped with Control-C. Both can be changed:

```bash
swift run vending-server --hostname 0.0.0.0 --port 8090
```

Each start is a new machine, idle and full of drinks.

## Running the client

In another terminal, with the server running:

```bash
swift run vend status
```

`swift run` builds the client first when needed. The built program can also be run directly, as `.build/debug/vend`.
Below, `vend` stands for either.

| Command | What it does |
|---|---|
| `vend status` | Shows the state, the credit, the coin return, the pickup, the stock, and the commands accepted now. |
| `vend products` | Shows the drinks, with their prices and how many are left. |
| `vend insert <cents>...` | Inserts coins, one at a time. Stops at the first coin not accepted. |
| `vend select <drink>` | Pushes the button of a drink: `coke-zero`, `pepsi-max` or `trocadero`. The change goes to the coin return. |
| `vend take-drink` | Takes the drink from the pickup. |
| `vend cancel` | Pushes the cancel button. The credit goes to the coin return. |
| `vend take-coins` | Takes the coins in the coin return. |
| `vend diagram` | Prints the state machine as a diagram, with the current state marked. `--format dot` gives Graphviz instead of Mermaid. |
| `vend break-down` | Breaks the machine down. |
| `vend repair` | Repairs the machine. |
| `vend refill` | Refills the machine. |

Every command takes `--server <url>`, for a server somewhere else than `http://127.0.0.1:8080`,
and `--json`, to print the JSON the server answers with. `vend help <command>` tells more about a command.

An event the machine does not accept is written to standard error, and the client exits with the status 1.

A purchase:

```
$ vend insert 100 100
Inserted $1.00: idle → hasCredit
Credit $1.00, coin return $0.00, pickup empty.
Inserted $1.00: hasCredit → hasCredit
Credit $2.00, coin return $0.00, pickup empty.
$ vend select pepsi-max
Selected Pepsi Max: hasCredit → drinkReady
Credit $0.00, coin return $0.50, pickup Pepsi Max.
$ vend select coke-zero
The event select is not accepted when the machine is at drinkReady.
Credit $0.00, coin return $0.50, pickup Pepsi Max.
$ vend take-drink
Took the drink: drinkReady → idle
Credit $0.00, coin return $0.50, pickup empty.
$ vend take-coins
Took $0.50.
```

## The API

The server answers with JSON, except for the diagram, which is text.

| Request | Answer |
|---|---|
| `GET /machine` | The state, the amounts and the events accepted. |
| `GET /products` | The drinks, with prices and stock. |
| `POST /events` | Processes the event in the body. 200 with the transition made, or 409 with why the event was not processed. |
| `POST /coin-return/take` | Takes the coins in the coin return. |
| `GET /diagram?format=mermaid` | The state machine as a diagram, `mermaid` or `dot`. |

An event is written with its values, and an event without values with an empty object:

```bash
curl -X POST -H 'Content-Type: application/json' -d '{"insertCoin":{"cents":100}}' http://127.0.0.1:8080/events
curl -X POST -H 'Content-Type: application/json' -d '{"select":{"drink":"cokeZero"}}' http://127.0.0.1:8080/events
curl -X POST -H 'Content-Type: application/json' -d '{"takeDrink":{}}' http://127.0.0.1:8080/events
```
