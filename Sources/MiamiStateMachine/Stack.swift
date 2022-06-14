import Foundation

/// A naive generic stack value type.
public struct Stack<E> {
    private var elements: [E] = []
    
    public var peek: E? {
        return elements.last
    }
    
    public var isEmpty: Bool {
        return elements.isEmpty
    }
    
    public var count: Int {
        return elements.count
    }

    public mutating func push(_ element: E) {
        self.elements.append(element)
    }
    
    public mutating func pop() -> E? {
        elements.popLast()
    }
}
