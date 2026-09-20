/// A first-in, first-out queue, implemented with two stacks.
///
/// Both `enqueue(_:)` and `dequeue()` are amortized O(1).
package struct QueueStack<Element>: Queue {

    /// Elements ready to be dequeued. Next in line is last.
    private var dequeueStack: [Element] = []

    /// Newly enqueued elements. The newest is last.
    private var enqueueStack: [Element] = []

    /// Creates an empty queue.
    package init() {}

    package var isEmpty: Bool {
        dequeueStack.isEmpty && enqueueStack.isEmpty
    }

    package var count: Int {
        dequeueStack.count + enqueueStack.count
    }

    package var peek: Element? {
        dequeueStack.last ?? enqueueStack.first
    }

    /// Adds an element to the back of the queue.
    /// - Parameter element: Element to add.
    package mutating func enqueue(_ element: Element) {
        enqueueStack.append(element)
    }

    /// Removes the element at the front of the queue.
    /// - Returns: The removed element, or `nil` if the queue is empty.
    @discardableResult
    package mutating func dequeue() -> Element? {
        if dequeueStack.isEmpty {
            dequeueStack = enqueueStack.reversed()
            enqueueStack.removeAll()
        }
        return dequeueStack.popLast()
    }
}

extension QueueStack: Sendable where Element: Sendable {}

extension QueueStack: CustomStringConvertible {
    package var description: String {
        String(describing: dequeueStack.reversed() + enqueueStack)
    }
}
