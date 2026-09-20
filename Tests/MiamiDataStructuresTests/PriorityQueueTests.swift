import Testing
import MiamiDataStructures

struct PriorityQueueTests {

    /// Element collections exercising the boundaries: empty, single,
    /// duplicates, already sorted and reversed.
    static let samples: [[Int]] = [
        [],
        [42],
        [3, 1, 3, 1, 2, 2],
        [1, 2, 3, 4, 5, 6, 7],
        [7, 6, 5, 4, 3, 2, 1],
        [12, -3, 8, 0, 25, 7, -3, 100, 1],
    ]

    /// Dequeues all elements of the queue, in order.
    private func drain(_ queue: PriorityQueue<Int>) -> [Int] {
        var queue = queue
        var dequeued: [Int] = []
        while let element = queue.dequeue() {
            dequeued.append(element)
        }
        return dequeued
    }

    @Test(arguments: samples)
    func dequeuesInAscendingOrder(elements: [Int]) {
        let queue = PriorityQueue(elements)

        #expect(queue.count == elements.count)
        #expect(drain(queue) == elements.sorted())
    }

    @Test(arguments: samples)
    func enqueuingKeepsAscendingOrder(elements: [Int]) {
        var queue = PriorityQueue<Int>()
        for element in elements {
            queue.enqueue(element)
        }

        #expect(queue.count == elements.count)
        #expect(drain(queue) == elements.sorted())
    }

    /// The graph algorithms enqueue and dequeue in turns, so the order has
    /// to hold then as well, and not only when draining a finished queue.
    @Test(arguments: [1, 2, 3] as [UInt64])
    func matchesSortedArrayWhenEnqueuingAndDequeuingInTurns(seed: UInt64) throws {
        var generator = SeededGenerator(seed: seed)
        var queue = PriorityQueue<Int>()
        var sorted: [Int] = []

        for step in 0 ..< 2_000 {
            if Bool.random(using: &generator) || sorted.isEmpty {
                // A small range of values gives many duplicates.
                let element = Int.random(in: -20 ... 20, using: &generator)
                queue.enqueue(element)
                sorted.insert(element, at: sorted.firstIndex { $0 > element } ?? sorted.endIndex)
            } else {
                try #require(queue.dequeue() == sorted.removeFirst(), "Step \(step)")
            }

            try #require(queue.peek == sorted.first, "Step \(step)")
            try #require(queue.count == sorted.count, "Step \(step)")
            try #require(queue.isEmpty == sorted.isEmpty, "Step \(step)")
        }
    }

    @Test func peekIsSmallestWithoutRemoving() {
        let queue = PriorityQueue([5, 2, 9])

        #expect(queue.peek == 2)
        #expect(queue.count == 3, "Peeking should not remove the element.")
    }

    @Test func emptyQueueHasNothingToDequeue() {
        var queue = PriorityQueue<Int>()

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.peek == nil)
        #expect(queue.dequeue() == nil)
    }

    @Test func copyIsIndependentOfOriginal() {
        let original = PriorityQueue([3, 1, 2])

        var copy = original
        copy.dequeue()
        copy.enqueue(0)

        #expect(drain(original) == [1, 2, 3])
        #expect(drain(copy) == [0, 2, 3])
    }
}
