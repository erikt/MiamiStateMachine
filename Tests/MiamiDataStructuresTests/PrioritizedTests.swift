import Testing
import MiamiDataStructures

struct PrioritizedTests {

    /// A value that cannot be compared on its own.
    private struct Job: Equatable {
        let name: String
    }

    @Test func valuesAreDequeuedByLowestPriorityFirst() {
        var queue = PriorityQueue<Prioritized<Job, Double>>()
        queue.enqueue(Prioritized(Job(name: "paint"), priority: 2.5))
        queue.enqueue(Prioritized(Job(name: "sand"), priority: 1))
        queue.enqueue(Prioritized(Job(name: "varnish"), priority: 7))
        queue.enqueue(Prioritized(Job(name: "clean"), priority: 0))

        var names: [String] = []
        while let next = queue.dequeue() {
            names.append(next.value.name)
        }

        #expect(names == ["clean", "sand", "paint", "varnish"])
    }

    @Test func comparesPrioritiesOnly() {
        let first = Prioritized("z", priority: 1)
        let second = Prioritized("a", priority: 2)
        let third = Prioritized("m", priority: 2)

        #expect(first < second, "The values should not take part in the comparison.")
        #expect(second == third, "Equal priorities should make equal prioritized values.")
        #expect(second.value == "a")
        #expect(second.priority == 2)
    }

    @Test func keepsAllValuesWithTheSamePriority() {
        var queue = PriorityQueue<Prioritized<Job, Int>>()
        for name in ["a", "b", "c"] {
            queue.enqueue(Prioritized(Job(name: name), priority: 1))
        }

        var names: Set<String> = []
        while let next = queue.dequeue() {
            names.insert(next.value.name)
        }

        // The order among equal priorities is unspecified.
        #expect(names == ["a", "b", "c"])
    }
}
