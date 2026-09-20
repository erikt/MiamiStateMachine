/// A last-in, first-out stack.
package struct Stack<Element> {
    private var storage: [Element] = []

    /// Creates an empty stack.
    package init() {}

    /// Creates a stack from the elements. The last element
    /// ends up on top of the stack.
    /// - Parameter elements: Initial elements of the stack.
    package init(_ elements: [Element]) {
        storage = elements
    }

    /// If the stack has no elements.
    package var isEmpty: Bool {
        storage.isEmpty
    }

    /// Number of elements in the stack.
    package var count: Int {
        storage.count
    }

    /// The element on top of the stack, without removing it.
    package var peek: Element? {
        storage.last
    }

    /// Pushes an element on top of the stack.
    /// - Parameter element: Element to push.
    package mutating func push(_ element: Element) {
        storage.append(element)
    }

    /// Removes the element on top of the stack.
    /// - Returns: The removed element, or `nil` if the stack is empty.
    @discardableResult
    package mutating func pop() -> Element? {
        storage.popLast()
    }
}

extension Stack: Sendable where Element: Sendable {}

extension Stack: ExpressibleByArrayLiteral {
    package init(arrayLiteral elements: Element...) {
        storage = elements
    }
}

extension Stack: CustomStringConvertible {
    package var description: String {
        storage.description
    }
}
