/// The streams of one kind created by a state machine and still in use,
/// as the continuations feeding them.
///
/// A stream is identified by a number, which is never used again by the
/// same registry. A stream can then be forgotten some time after it was
/// cancelled, without the risk of forgetting a newer stream.
struct StreamRegistry<Element: Sendable>: Sendable {

    /// The continuations of the streams in use, by the identity of the stream.
    private var continuations: [UInt64: AsyncStream<Element>.Continuation] = [:]

    /// The identity of the next stream to be added.
    private var nextID: UInt64 = 0

    /// Number of streams in use.
    var count: Int {
        return continuations.count
    }

    /// Adds a new stream, by its continuation.
    /// - Parameter continuation: The continuation feeding the stream.
    /// - Returns: The identity of the stream.
    mutating func add(_ continuation: AsyncStream<Element>.Continuation) -> UInt64 {
        let id = nextID
        nextID += 1
        continuations[id] = continuation
        return id
    }

    /// Forgets a stream no longer in use. Nothing happens
    /// if the stream is already forgotten.
    /// - Parameter id: The identity of the stream.
    mutating func remove(_ id: UInt64) {
        continuations[id] = nil
    }

    /// Delivers an element to every stream.
    /// - Parameter element: The element to deliver.
    func yield(_ element: Element) {
        for continuation in continuations.values {
            continuation.yield(element)
        }
    }

    /// Finishes every stream, and forgets them all.
    mutating func finishAll() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }
}
