import Foundation

/// TODO: Documentation
public struct Stack<T> {
    private var storage: [T] = []
    
    public init() { }
    
    public init(_ elements: [T]) {
        storage = elements
    }
    
    public mutating func push(_ element: T) {
        storage.append(element)
    }
    
    @discardableResult
    public mutating func pop() -> T? {
        storage.popLast()
    }
    
    public func peek() -> T? {
        storage.last
    }
    
    public var isEmpty: Bool {
        peek() == nil
    }
}

extension Stack: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: T...) {
        storage = elements
    }
}
