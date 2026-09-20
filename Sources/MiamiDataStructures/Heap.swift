/// A binary heap, keeping the element with the highest priority
/// at the root.
///
/// The priority is decided by the ordering predicate given when the
/// heap is created. `Heap(by: <)` is a min-heap and `Heap(by: >)`
/// is a max-heap.
package struct Heap<Element> {

    /// The elements of the heap, in heap order.
    package private(set) var elements: [Element]

    /// Predicate returning `true` if the first element has
    /// higher priority than the second element.
    private let hasHigherPriority: (Element, Element) -> Bool

    /// Creates a heap from the elements, ordered by a predicate.
    /// - Parameters:
    ///   - elements: Initial elements of the heap, in any order.
    ///   - hasHigherPriority: Predicate returning `true` if its first
    ///   argument should be removed from the heap before its second argument.
    /// - Complexity: O(*n*), where *n* is the number of elements.
    package init(_ elements: [Element] = [],
                 by hasHigherPriority: @escaping (Element, Element) -> Bool)
    {
        self.elements = elements
        self.hasHigherPriority = hasHigherPriority

        for index in stride(from: elements.count / 2 - 1, through: 0, by: -1) {
            siftDown(from: index)
        }
    }

    /// If the heap has no elements.
    package var isEmpty: Bool {
        elements.isEmpty
    }

    /// Number of elements in the heap.
    package var count: Int {
        elements.count
    }

    /// The element with the highest priority, without removing it.
    package var peek: Element? {
        elements.first
    }

    /// Inserts an element in the heap.
    /// - Parameter element: Element to insert.
    /// - Complexity: O(log *n*)
    package mutating func insert(_ element: Element) {
        elements.append(element)
        siftUp(from: elements.count - 1)
    }

    /// Removes the element with the highest priority.
    /// - Returns: The removed element, or `nil` if the heap is empty.
    /// - Complexity: O(log *n*)
    @discardableResult
    package mutating func remove() -> Element? {
        guard !isEmpty else {
            return nil
        }

        elements.swapAt(0, count - 1)
        let removed = elements.removeLast()
        siftDown(from: 0)
        return removed
    }

    /// Removes the element at an index of `elements`.
    /// - Parameter index: Index of the element to remove.
    /// - Returns: The removed element, or `nil` if the index is out of bounds.
    /// - Complexity: O(log *n*)
    @discardableResult
    package mutating func remove(at index: Int) -> Element? {
        guard elements.indices.contains(index) else {
            return nil
        }

        elements.swapAt(index, count - 1)
        let removed = elements.removeLast()

        if index < count {
            siftDown(from: index)
            siftUp(from: index)
        }
        return removed
    }

    // MARK: - Private methods

    private func leftChildIndex(ofParentAt index: Int) -> Int {
        (2 * index) + 1
    }

    private func rightChildIndex(ofParentAt index: Int) -> Int {
        (2 * index) + 2
    }

    private func parentIndex(ofChildAt index: Int) -> Int {
        (index - 1) / 2
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = leftChildIndex(ofParentAt: parent)
            let right = rightChildIndex(ofParentAt: parent)
            var candidate = parent

            if left < count && hasHigherPriority(elements[left], elements[candidate]) {
                candidate = left
            }

            if right < count && hasHigherPriority(elements[right], elements[candidate]) {
                candidate = right
            }

            if candidate == parent {
                return
            }

            elements.swapAt(parent, candidate)
            parent = candidate
        }
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = parentIndex(ofChildAt: child)
        while child > 0 && hasHigherPriority(elements[child], elements[parent]) {
            elements.swapAt(child, parent)
            child = parent
            parent = parentIndex(ofChildAt: child)
        }
    }
}

extension Heap where Element: Equatable {

    /// The index in `elements` of the first found element equal to an element.
    /// - Parameter element: Element to search for.
    /// - Returns: Index of the element, or `nil` if it is not in the heap.
    /// - Complexity: O(*n*), but subtrees which can not contain the
    /// element are skipped.
    package func firstIndex(of element: Element) -> Int? {
        firstIndex(of: element, startingAt: 0)
    }

    private func firstIndex(of element: Element, startingAt index: Int) -> Int? {
        if index >= count {
            return nil
        }

        if hasHigherPriority(element, elements[index]) {
            // Everything below this index has lower priority
            // than the element, so it can not be in this subtree.
            return nil
        }

        if element == elements[index] {
            return index
        }

        return firstIndex(of: element, startingAt: leftChildIndex(ofParentAt: index))
            ?? firstIndex(of: element, startingAt: rightChildIndex(ofParentAt: index))
    }
}

extension Heap: CustomStringConvertible {
    package var description: String {
        elements.description
    }
}
