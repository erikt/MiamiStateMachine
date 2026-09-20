/// A queue where the element with the highest priority is
/// dequeued first. Implemented with a `Heap`.
///
/// The priority is decided by the ordering predicate given when the
/// queue is created. `PriorityQueue(by: <)` dequeues the smallest
/// element first.
///
/// Elements with the same priority are dequeued in an unspecified order.
package struct PriorityQueue<Element>: Queue {

    private var heap: Heap<Element>

    /// Creates a priority queue from the elements, ordered by a predicate.
    /// - Parameters:
    ///   - elements: Initial elements of the queue, in any order.
    ///   - hasHigherPriority: Predicate returning `true` if its first
    ///   argument should be dequeued before its second argument.
    package init(_ elements: [Element] = [],
                 by hasHigherPriority: @escaping (Element, Element) -> Bool)
    {
        heap = Heap(elements, by: hasHigherPriority)
    }

    package var isEmpty: Bool {
        heap.isEmpty
    }

    package var count: Int {
        heap.count
    }

    package var peek: Element? {
        heap.peek
    }

    /// Adds an element to the queue.
    /// - Parameter element: Element to add.
    /// - Complexity: O(log *n*)
    package mutating func enqueue(_ element: Element) {
        heap.insert(element)
    }

    /// Removes the element with the highest priority.
    /// - Returns: The removed element, or `nil` if the queue is empty.
    /// - Complexity: O(log *n*)
    @discardableResult
    package mutating func dequeue() -> Element? {
        heap.remove()
    }
}
