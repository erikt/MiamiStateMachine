/// A collection where elements are added with `enqueue(_:)` and
/// removed with `dequeue()`, in an order decided by the conforming type.
package protocol Queue<Element> {
    associatedtype Element

    /// If the queue has no elements.
    var isEmpty: Bool { get }

    /// Number of elements in the queue.
    var count: Int { get }

    /// The element next in line to be dequeued, without removing it.
    var peek: Element? { get }

    /// Adds an element to the queue.
    /// - Parameter element: Element to add.
    mutating func enqueue(_ element: Element)

    /// Removes the element next in line.
    /// - Returns: The removed element, or `nil` if the queue is empty.
    mutating func dequeue() -> Element?
}
