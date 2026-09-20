/// A value together with the priority deciding its place in a `PriorityQueue`.
/// The value with the lowest priority is dequeued first.
///
/// Prioritized values are compared by their priorities only. Two of them
/// are equal when their priorities are equal, whatever their values are.
package struct Prioritized<Value, Priority: Comparable>: Comparable {

    /// The value to queue.
    package let value: Value

    /// The priority of the value. Lower is dequeued earlier.
    package let priority: Priority

    /// Creates a value with a priority.
    /// - Parameters:
    ///   - value: The value to queue.
    ///   - priority: The priority of the value. Lower is dequeued earlier.
    package init(_ value: Value, priority: Priority) {
        self.value = value
        self.priority = priority
    }

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.priority == rhs.priority
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.priority < rhs.priority
    }
}

extension Prioritized: Sendable where Value: Sendable, Priority: Sendable {}
