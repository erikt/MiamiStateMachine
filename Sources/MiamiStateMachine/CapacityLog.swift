import DequeModule

/// A log for logging generic elements, but having the log
/// restricted to a limited amount of elements. If the max
/// capacity has been reached, the oldest element is dropped
/// from the log.
///
/// The log is a collection of its elements, from the oldest to the
/// newest. It can be iterated, and the elements can be accessed by
/// their position, where the oldest element is at position zero.
///
///     for transition in log {
///         print(transition)
///     }
///
///     let oldest = log.first
///     let secondNewest = log[log.count - 2]
///
/// The log can be encoded when its elements can, and decoded when they
/// can be decoded. It is saved with its max capacity, so a decoded log
/// goes on dropping its oldest elements like the log encoded. The keys
/// are `capacity`, left out for a log without max capacity, and
/// `elements`, with the elements from the oldest to the newest.
///
/// The log is implemented with the Apple Swift Collection
/// deque and should be performant.
public struct CapacityLog<Element> {
    private var log: Deque<Element> = []
    private let capacity: UInt?
    
    /// The newest element in the log. It is nil if the log is empty.
    public var last: Element? {
        return log.last
    }
    
    /// The oldest element in the log. It is nil if the log is empty.
    public var first: Element? {
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
    
    /// Append (push) a new element to the log. If max capacity of the log
    /// has been reached, the oldest element in the log will be removed.
    /// - Parameter element: Element to be appended to the log.
    public mutating func append(_ element: Element) {
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
    /// - Returns: Newest element in the log. It is nil if the log is empty.
    public mutating func popLast() -> Element? {
        return log.popLast()
    }
    
    /// Pop the oldest/first element from the log.
    /// - Returns: Oldest element in the log. It is nil if the log is empty.
    public mutating func popFirst() -> Element? {
        return log.popFirst()
    }
}

extension CapacityLog: Sendable where Element: Sendable { }

extension CapacityLog {

    /// The keys of an encoded log.
    private enum CodingKeys: String, CodingKey {
        case capacity, elements
    }
}

extension CapacityLog: Encodable where Element: Encodable {

    /// Encodes the max capacity of the log, if it has one, and
    /// its elements from the oldest to the newest.
    /// - Parameter encoder: The encoder to write the log to.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(capacity, forKey: .capacity)

        var elements = container.nestedUnkeyedContainer(forKey: .elements)
        for element in log {
            try elements.encode(element)
        }
    }
}

extension CapacityLog: Decodable where Element: Decodable {

    /// Create a log by decoding its max capacity and its elements.
    ///
    /// The elements are appended to the log one by one, from the oldest
    /// to the newest. If there are more elements than the max capacity,
    /// only the newest are kept.
    /// - Parameter decoder: The decoder to read the log from.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(capacity: try container.decodeIfPresent(UInt.self, forKey: .capacity))

        var elements = try container.nestedUnkeyedContainer(forKey: .elements)
        while !elements.isAtEnd {
            append(try elements.decode(Element.self))
        }
    }
}

extension CapacityLog: RandomAccessCollection {

    /// The position of the oldest element. Always zero.
    public var startIndex: Int {
        return log.startIndex
    }

    /// The position after the newest element. Equal to `count`.
    public var endIndex: Int {
        return log.endIndex
    }

    /// Accesses the element at a position, where the oldest element
    /// is at position zero and the newest at `count - 1`.
    /// - Parameter position: The position of the element. It has
    /// to be a valid position of the log.
    /// - Complexity: O(1)
    public subscript(position: Int) -> Element {
        return log[position]
    }
}

extension CapacityLog: CustomStringConvertible {
    public var description: String {
        return log.description
    }
}

extension CapacityLog: CustomDebugStringConvertible {
    public var debugDescription: String {
        return log.map { "\($0)" }.joined(separator: "\n")
    }
}
