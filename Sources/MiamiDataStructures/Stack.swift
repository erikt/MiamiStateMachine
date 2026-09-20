/// A last-in, first-out stack.
package struct Stack<Element> {

    private var elements: [Element]

    /// Creates a stack from the elements. The last
    /// element ends up on top of the stack.
    /// - Parameter elements: Initial elements of the stack.
    package init(_ elements: [Element] = []) {
        self.elements = elements
    }

    /// If the stack has no elements.
    package var isEmpty: Bool {
        elements.isEmpty
    }

    /// Number of elements in the stack.
    package var count: Int {
        elements.count
    }

    /// The element on top of the stack, without removing it.
    /// It is the element pushed last, and the next to be popped.
    package var top: Element? {
        elements.last
    }

    /// Pushes an element on top of the stack.
    /// - Parameter element: Element to push.
    /// - Complexity: Amortized O(1)
    package mutating func push(_ element: Element) {
        elements.append(element)
    }

    /// Removes the element on top of the stack.
    /// - Returns: The removed element, or `nil` if the stack is empty.
    /// - Complexity: O(1)
    @discardableResult
    package mutating func pop() -> Element? {
        elements.popLast()
    }
}

extension Stack: Sendable where Element: Sendable {}

extension Stack: CustomStringConvertible {
    package var description: String {
        elements.description
    }
}
