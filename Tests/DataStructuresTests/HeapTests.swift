import Testing
import DataStructures

struct HeapTests {

    /// Element collections exercising the boundaries: empty, single,
    /// duplicates, already sorted and reversed.
    static let samples: [[Int]] = [
        [],
        [42],
        [3, 1, 3, 1, 2, 2],
        [1, 2, 3, 4, 5, 6, 7],
        [7, 6, 5, 4, 3, 2, 1],
        [12, -3, 8, 0, 25, 7, -3, 100, 1],
    ]

    /// Removes all elements from the heap, in priority order.
    private func drain(_ heap: Heap<Int>) -> [Int] {
        var heap = heap
        var removed: [Int] = []
        while let element = heap.remove() {
            removed.append(element)
        }
        return removed
    }

    @Test(arguments: samples)
    func minHeapRemovesInAscendingOrder(elements: [Int]) {
        let heap = Heap(elements, by: <)
        #expect(drain(heap) == elements.sorted())
    }

    @Test(arguments: samples)
    func maxHeapRemovesInDescendingOrder(elements: [Int]) {
        let heap = Heap(elements, by: >)
        #expect(drain(heap) == elements.sorted(by: >))
    }

    @Test(arguments: samples)
    func insertingKeepsPriorityOrder(elements: [Int]) {
        var heap = Heap<Int>(by: <)
        for element in elements {
            heap.insert(element)
        }

        #expect(heap.count == elements.count)
        #expect(drain(heap) == elements.sorted())
    }

    @Test func peekIsHighestPriorityWithoutRemoving() {
        let heap = Heap([5, 2, 9], by: <)

        #expect(heap.peek == 2)
        #expect(heap.count == 3, "Peeking should not remove the element.")
    }

    @Test func emptyHeapHasNothingToRemove() {
        var heap = Heap<Int>(by: <)

        #expect(heap.isEmpty)
        #expect(heap.peek == nil)
        #expect(heap.remove() == nil)
    }

    @Test(arguments: 0 ..< 9)
    func removingAtIndexKeepsPriorityOrder(index: Int) throws {
        let elements = [12, -3, 8, 0, 25, 7, -3, 100, 1]
        var heap = Heap(elements, by: <)
        let expectedRemoved = heap.elements[index]

        let removed = heap.remove(at: index)
        #expect(removed == expectedRemoved)

        var expectedRemaining = elements.sorted()
        let sortedIndex = try #require(expectedRemaining.firstIndex(of: expectedRemoved))
        expectedRemaining.remove(at: sortedIndex)
        #expect(drain(heap) == expectedRemaining)
    }

    @Test(arguments: [-1, 3, 100])
    func removingAtIndexOutOfBoundsRemovesNothing(index: Int) {
        var heap = Heap([1, 2, 3], by: <)

        #expect(heap.remove(at: index) == nil)
        #expect(heap.count == 3)
    }

    @Test(arguments: [12, -3, 8, 0, 25, 7, 100, 1])
    func firstIndexFindsElement(element: Int) throws {
        let heap = Heap([12, -3, 8, 0, 25, 7, -3, 100, 1], by: <)

        let index = try #require(heap.firstIndex(of: element))
        #expect(heap.elements[index] == element)
    }

    @Test(arguments: [-100, 5, 1000])
    func firstIndexOfMissingElementIsNil(element: Int) {
        let heap = Heap([12, -3, 8, 0, 25, 7, -3, 100, 1], by: <)
        #expect(heap.firstIndex(of: element) == nil)
    }
}
