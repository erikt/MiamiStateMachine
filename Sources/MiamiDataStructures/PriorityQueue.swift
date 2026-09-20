import HeapModule

/// A queue where the smallest element is dequeued first. Implemented
/// with the `Heap` of Swift Collections.
///
/// To queue values that cannot be compared, or to queue values by
/// something other than their own ordering, wrap them in `Prioritized`.
///
/// Elements that are equal are dequeued in an unspecified order.
package struct PriorityQueue<Element: Comparable> {

    private var heap: Heap<Element>

    /// Creates a priority queue from the elements.
    /// - Parameter elements: Initial elements of the queue, in any order.
    /// - Complexity: O(*n*), where *n* is the number of elements.
    package init(_ elements: [Element] = []) {
        heap = Heap(elements)
    }

    /// If the queue has no elements.
    package var isEmpty: Bool {
        heap.isEmpty
    }

    /// Number of elements in the queue.
    package var count: Int {
        heap.count
    }

    /// The smallest element, without removing it.
    /// It is the next element to be dequeued.
    package var first: Element? {
        heap.min
    }

    /// Adds an element to the queue.
    /// - Parameter element: Element to add.
    /// - Complexity: O(log *n*)
    package mutating func enqueue(_ element: Element) {
        heap.insert(element)
    }

    /// Removes the smallest element.
    /// - Returns: The removed element, or `nil` if the queue is empty.
    /// - Complexity: O(log *n*)
    @discardableResult
    package mutating func dequeue() -> Element? {
        heap.popMin()
    }
}

extension PriorityQueue: Sendable where Element: Sendable {}
