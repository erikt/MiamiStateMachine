import Testing
import MiamiDataStructures

struct QueueTests {

    @Test func dequeuesFirstInFirstOut() {
        var queue = Queue<Int>()
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
        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        #expect(queue.dequeue() == 1)

        // 2 is still in the queue, and should come
        // out before the elements enqueued after it.
        queue.enqueue(3)
        queue.enqueue(4)

        #expect(queue.count == 3)
        #expect(queue.description == "[2, 3, 4]")
        #expect(queue.dequeue() == 2)
        #expect(queue.dequeue() == 3)
        #expect(queue.dequeue() == 4)
        #expect(queue.isEmpty)
    }

    @Test func firstIsFrontOfQueueWithoutRemoving() {
        var queue = Queue<Int>()
        queue.enqueue(1)
        queue.enqueue(2)
        #expect(queue.first == 1, "The first enqueued should be at the front.")

        queue.dequeue()
        queue.enqueue(3)
        #expect(queue.first == 2, "The next in line should be at the front after a dequeue.")
        #expect(queue.count == 2, "Looking at the front should not remove the element.")
    }

    @Test func firstElementIsAtTheFrontWhenCreatedFromElements() {
        var queue = Queue([1, 2, 3])

        #expect(queue.first == 1)
        #expect(queue.dequeue() == 1)
        #expect(queue.dequeue() == 2)
        #expect(queue.count == 1)
    }

    @Test func emptyQueueHasNothingToDequeue() {
        var queue = Queue<Int>()

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.first == nil)
        #expect(queue.dequeue() == nil)
    }

    @Test func isNotEmptyBeforeAnythingIsDequeued() {
        var queue = Queue<Int>()
        queue.enqueue(1)

        #expect(queue.isEmpty == false)
        #expect(queue.count == 1)
    }

    @Test func describesElementsFromFrontToBack() {
        var queue = Queue<Int>()
        for element in 1 ... 4 {
            queue.enqueue(element)
        }
        queue.dequeue()
        queue.enqueue(5)

        // From the front of the queue to the back.
        #expect(queue.description == "[2, 3, 4, 5]")
    }

    @Test func copyIsIndependentOfOriginal() {
        var original = Queue<Int>()
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
        var queue = Queue<Int>()
        var array: [Int] = []

        for step in 0 ..< 2_000 {
            if Bool.random(using: &generator) || array.isEmpty {
                queue.enqueue(step)
                array.append(step)
            } else {
                try #require(queue.dequeue() == array.removeFirst(), "Step \(step)")
            }

            try #require(queue.first == array.first, "Step \(step)")
            try #require(queue.count == array.count, "Step \(step)")
            try #require(queue.isEmpty == array.isEmpty, "Step \(step)")
            try #require(queue.description == array.description, "Step \(step)")
        }
    }
}
