import Testing
import DataStructures

struct PriorityQueueTests {

    @Test func dequeuesHighestPriorityFirst() {
        var queue = PriorityQueue([4, 1, 3], by: <)
        queue.enqueue(2)
        queue.enqueue(0)

        var dequeued: [Int] = []
        while let element = queue.dequeue() {
            dequeued.append(element)
        }

        #expect(dequeued == [0, 1, 2, 3, 4])
    }

    @Test func priorityIsDecidedByPredicate() {
        // Longest string first.
        var queue = PriorityQueue(["aa", "a", "aaaa", "aaa"]) { $0.count > $1.count }

        #expect(queue.dequeue() == "aaaa")
        #expect(queue.dequeue() == "aaa")
    }

    @Test func peekIsNextInLineWithoutRemoving() {
        let queue = PriorityQueue([5, 2, 9], by: <)

        #expect(queue.peek == 2)
        #expect(queue.count == 3, "Peeking should not remove the element.")
    }

    @Test func emptyQueueHasNothingToDequeue() {
        var queue = PriorityQueue<Int>(by: <)

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.peek == nil)
        #expect(queue.dequeue() == nil)
    }
}
