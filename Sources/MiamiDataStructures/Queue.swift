import DequeModule

/// A first-in, first-out queue. Implemented with the `Deque`
/// of Swift Collections.
package struct Queue<Element> {

    private var elements: Deque<Element>

    /// Creates a queue from the elements. The first
    /// element ends up at the front of the queue.
    /// - Parameter elements: Initial elements of the queue.
    package init(_ elements: [Element] = []) {
        self.elements = Deque(elements)
    }

    /// If the queue has no elements.
    package var isEmpty: Bool {
        elements.isEmpty
    }

    /// Number of elements in the queue.
    package var count: Int {
        elements.count
    }

    /// The element at the front of the queue, without removing it.
    /// It is the element waiting the longest, and the next to be dequeued.
    package var first: Element? {
        elements.first
    }

    /// Adds an element to the back of the queue.
    /// - Parameter element: Element to add.
    /// - Complexity: Amortized O(1)
    package mutating func enqueue(_ element: Element) {
        elements.append(element)
    }

    /// Removes the element at the front of the queue.
    /// - Returns: The removed element, or `nil` if the queue is empty.
    /// - Complexity: O(1)
    @discardableResult
    package mutating func dequeue() -> Element? {
        elements.popFirst()
    }
}

extension Queue: Sendable where Element: Sendable {}

extension Queue: CustomStringConvertible {
    package var description: String {
        elements.description
    }
}
