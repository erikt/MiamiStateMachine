import Testing
import MiamiDataStructures

struct QueueStackTests {

    @Test func dequeuesFirstInFirstOut() {
        var queue = QueueStack<Int>()
        for element in 1 ... 5 {
            queue.enqueue(element)
        }

        var dequeued: [Int] = []
        while let element = queue.dequeue() {
            dequeued.append(element)
        }

        #expect(dequeued == [1, 2, 3, 4, 5])
    }

    @Test func keepsOrderWhenEnqueuingBetweenDequeues() {
        var queue = QueueStack<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        #expect(queue.dequeue() == 1)

        // 2 is now ready to be dequeued, while
        // 3 and 4 are waiting behind it.
        queue.enqueue(3)
        queue.enqueue(4)

        #expect(queue.count == 3)
        #expect(queue.description == "[2, 3, 4]")
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == 4)
        #expect(queue.isEmpty)
    }

    @Test func peekIsFrontOfQueueWithoutRemoving() {
        var queue = QueueStack<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        #expect(queue.peek == 1, "Should peek at the front before anything has been dequeued.")

        queue.dequeue()
        queue.enqueue(3)
        #expect(queue.peek == 2, "Should peek at the front after an element has been dequeued.")
        #expect(queue.count == 2, "Peeking should not remove the element.")
    }

    @Test func emptyQueueHasNothingToDequeue() {
        var queue = QueueStack<Int>()

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.peek == nil)
        #expect(queue.dequeue() == nil)
    }

    @Test func isNotEmptyBeforeAnythingIsDequeued() {
        var queue = QueueStack<Int>()
        queue.enqueue(1)

        #expect(queue.isEmpty == false)
        #expect(queue.count == 1)
    }

    @Test func describesElementsFromFrontToBack() {
        var queue = QueueStack<Int>()
        for element in 1 ... 4 {
            queue.enqueue(element)
        }
        queue.dequeue()
        queue.enqueue(5)

        // 2, 3 and 4 are ready to be dequeued, while 5 is waiting behind them.
        #expect(queue.description == "[2, 3, 4, 5]")
    }

    @Test func copyIsIndependentOfOriginal() {
        var original = QueueStack<Int>()
        original.enqueue(1)
        original.enqueue(2)

        var copy = original
        copy.dequeue()
        copy.enqueue(3)

        #expect(original.description == "[1, 2]")
        #expect(copy.description == "[2, 3]")
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func matchesArrayWhenEnqueuingAndDequeuingInTurns(seed: UInt64) throws {
        var generator = SeededGenerator(seed: seed)
        var queue = QueueStack<Int>()
        var array: [Int] = []

        for step in 0 ..< 2_000 {
            if Bool.random(using: &generator) || array.isEmpty {
                queue.enqueue(step)
                array.append(step)
            } else {
                try #require(queue.dequeue() == array.removeFirst(), "Step \(step)")
            }

            try #require(queue.peek == array.first, "Step \(step)")
            try #require(queue.count == array.count, "Step \(step)")
            try #require(queue.isEmpty == array.isEmpty, "Step \(step)")
            try #require(queue.description == array.description, "Step \(step)")
        }
    }
}
