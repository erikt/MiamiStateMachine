import DequeModule

/// A log for logging generic elements, but having the log
/// restricted to a limited amount of elements. If the max
/// capacity has been reached, the oldest element is dropped
/// from the log.
///
/// The log is implemented with the Apple Swift Collection
/// deque and should be performant.
public struct RestrictedLog<Element: Hashable> {
    private var log: Deque<Element> = []
    private var capacity: UInt?
    
    /// Peek at the latest element in the log.
    public var peek: Element? {
        return log.last
    }
    
    /// Peek at the oldest element in the log.
    public var peekOldest: Element? {
        return log.first
    }
    
    /// Is the log empty.
    public var isEmpty: Bool {
        return log.isEmpty
    }
    
    /// Count of log entries.
    public var count: Int {
        return log.count
    }
    
    /// Create a log with a max capacity. If the max capacity is not
    /// set, the log memory is treated as unlimited.
    /// - Parameter capacity: The max capacity.
    public init(capacity: UInt? = nil) {
        self.capacity = capacity
    }
    
    /// Push a new element to the log.
    /// - Parameter element: Element to be pushed on the log.
    public mutating func push(_ element: Element) {
        if let capacity = capacity {
            // There is a max capacity set.
            if count < capacity {
                // Max capacity not reached, just append to log.
                log.append(element)
            } else {
                // Max capacity reached. Remove oldest log entry,
                // then append the new log entry.
                log.append(element)
                log.removeFirst()
            }
        } else {
            // No max capacity set. Treat log as unlimited.
            log.append(element)
        }
    }
    
    /// Pop the newest/last element from the log.
    /// - Returns: Newest element in the log.
    public mutating func pop() -> Element? {
        return log.popLast()
    }
    
    /// Pop the oldest/first element from the log.
    /// - Returns: Oldest element in the log.
    public mutating func popOldest() -> Element? {
        return log.popFirst()
    }
}
