import Foundation

/// TODO: Documentation
public struct PriorityQueue<Element: Equatable>: Queue {
    
    private var heap: Heap<Element>
    
    public init(sort: @escaping (Element, Element) -> Bool, elements: [Element] = []) {
        heap = Heap(sort: sort, elements: elements)
    }
    
    public var isEmpty: Bool {
        heap.isEmpty
    }
    
    public var peek: Element? {
        heap.peek()
    }
    
    @discardableResult
    public mutating func enqueue(_ element: Element) -> Bool {
        heap.insert(element)
        return true
    }
    
    @discardableResult
    public mutating func dequeue() -> Element? {
        heap.remove()
    }
}
