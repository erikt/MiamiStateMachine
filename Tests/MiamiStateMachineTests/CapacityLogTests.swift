import Testing
import MiamiStateMachine

struct CapacityLogTests {

    /// Pops all elements of the log, the oldest first.
    private func drain(_ log: CapacityLog<Int>) -> [Int] {
        var log = log
        var elements: [Int] = []
        while let element = log.popOldest() {
            elements.append(element)
        }
        return elements
    }

    @Test(arguments: [0, 1, 3, 10] as [UInt])
    func keepsTheNewestElementsUpToItsCapacity(capacity: UInt) {
        var log = CapacityLog<Int>(capacity: capacity)

        for element in 1 ... 10 {
            log.append(element)
            #expect(log.count <= capacity, "The log should never grow past its capacity.")
        }

        let expected = Array((1 ... 10).suffix(Int(capacity)))
        #expect(drain(log) == expected)
        #expect(log.count == expected.count)
        #expect(log.peek == expected.last)
        #expect(log.peekOldest == expected.first)
    }

    @Test func keepsEverythingWithoutCapacity() {
        var log = CapacityLog<Int>()
        for element in 1 ... 1_000 {
            log.append(element)
        }

        #expect(log.count == 1_000)
        #expect(log.peekOldest == 1)
        #expect(log.peek == 1_000)
    }

    @Test func popsNewestAndOldest() {
        var log = CapacityLog<Int>(capacity: 3)
        for element in 1 ... 5 {
            log.append(element)
        }

        // Left in the log are 3, 4 and 5.
        #expect(log.pop() == 5)
        #expect(log.popOldest() == 3)
        #expect(log.pop() == 4)
        #expect(log.pop() == nil)
        #expect(log.popOldest() == nil)
    }

    @Test func hasRoomAgainAfterPopping() {
        var log = CapacityLog<Int>(capacity: 2)
        log.append(1)
        log.append(2)
        _ = log.pop()
        log.append(3)

        #expect(drain(log) == [1, 3])
    }

    @Test func isEmptyUntilAnElementIsAppended() {
        var log = CapacityLog<Int>(capacity: 2)
        #expect(log.isEmpty)
        #expect(log.peek == nil)
        #expect(log.peekOldest == nil)

        log.append(1)
        #expect(log.isEmpty == false)

        _ = log.pop()
        #expect(log.isEmpty)
    }

    @Test func logWithoutRoomStaysEmpty() {
        var log = CapacityLog<Int>(capacity: 0)
        log.append(1)

        #expect(log.isEmpty)
        #expect(log.count == 0)
    }

    // MARK: - Collection

    @Test func iteratesFromOldestToNewest() {
        var log = CapacityLog<Int>(capacity: 3)
        for element in 1 ... 5 {
            log.append(element)
        }

        var iterated: [Int] = []
        for element in log {
            iterated.append(element)
        }

        #expect(iterated == [3, 4, 5])
        #expect(Array(log) == [3, 4, 5])
        #expect(log.reversed() == [5, 4, 3])
        #expect(log.count == 3, "Iterating should not remove any elements.")
    }

    @Test func elementsAreAccessedByPositionWithTheOldestFirst() {
        var log = CapacityLog<Int>(capacity: 3)
        for element in 1 ... 5 {
            log.append(element)
        }

        #expect(log.indices == 0 ..< 3)
        #expect(log[0] == 3)
        #expect(log[1] == 4)
        #expect(log[log.count - 1] == 5)
        #expect(log.first == log.peekOldest)
        #expect(log.last == log.peek)
        #expect(log.suffix(2) == [4, 5])
    }

    @Test func positionsFollowTheElementsLeftInTheLog() {
        var log = CapacityLog<Int>()
        for element in 1 ... 4 {
            log.append(element)
        }
        _ = log.popOldest()
        _ = log.pop()

        #expect(Array(log) == [2, 3])
        #expect(log[0] == 2)
    }

    @Test func emptyLogHasNothingToIterate() {
        let log = CapacityLog<Int>(capacity: 3)

        #expect(Array(log) == [])
        #expect(log.indices.isEmpty)
        #expect(log.first == nil)
        #expect(log.last == nil)
    }

    @Test func describesElementsFromOldestToNewest() {
        var log = CapacityLog<Int>(capacity: 3)
        for element in 1 ... 4 {
            log.append(element)
        }

        #expect(log.description == "[2, 3, 4]")
        #expect(log.debugDescription == "2\n3\n4")
    }
}
