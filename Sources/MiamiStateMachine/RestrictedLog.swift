import DequeModule

public struct RestrictedLog<Element: Hashable> {
    private var log: Deque<Element> = []
    private var capacity: Int
    
    public var peek: Element? {
        return log.last
    }
    
    public var peekOldest: Element? {
        return log.first
    }
    
    public var isEmpty: Bool {
        return log.isEmpty
    }
    
    public var count: Int {
        return log.count
    }
    
    public init(capacity: Int) {
        self.capacity = capacity
    }
    
    public mutating func push(_ element: Element) {
        if count < capacity {
            log.append(element)
        } else {
            log.append(element)
            log.removeFirst()
        }
    }
    
    public mutating func pop() -> Element? {
        return log.popLast()
    }    
}
