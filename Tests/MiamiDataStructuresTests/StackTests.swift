import Testing
import MiamiDataStructures

struct StackTests {

    @Test func popsLastInFirstOut() {
        var stack = Stack<Int>()
        for element in 1 ... 3 {
            stack.push(element)
        }

        #expect(stack.pop() == 3)
        #expect(stack.pop() == 2)
        #expect(stack.pop() == 1)
        #expect(stack.pop() == nil)
    }

    @Test func lastElementIsOnTopWhenCreatedFromElements() {
        var stack = Stack([1, 2, 3])

        #expect(stack.top == 3)
        #expect(stack.pop() == 3)
        #expect(stack.pop() == 2)
    }

    @Test func topIsLastPushedWithoutRemoving() {
        var stack = Stack(["a", "b"])
        stack.push("c")

        #expect(stack.top == "c")
        #expect(stack.count == 3, "Looking at the top should not remove the element.")
    }

    @Test func emptyStackHasNothingToPop() {
        var stack = Stack<Int>()

        #expect(stack.isEmpty)
        #expect(stack.count == 0)
        #expect(stack.top == nil)
        #expect(stack.pop() == nil)
    }

    @Test func describesElementsFromBottomToTop() {
        var stack = Stack([1, 2, 3])
        stack.pop()
        stack.push(4)

        #expect(stack.description == "[1, 2, 4]")
    }

    @Test func copyIsIndependentOfOriginal() {
        let original = Stack([1, 2])

        var copy = original
        copy.pop()
        copy.push(3)

        #expect(original.description == "[1, 2]")
        #expect(copy.description == "[1, 3]")
    }

    @Test func countFollowsPushesAndPops() {
        var stack = Stack<Int>()
        for element in 1 ... 10 {
            stack.push(element)
        }
        #expect(stack.count == 10)

        stack.pop()
        #expect(stack.count == 9)
        #expect(stack.isEmpty == false)
    }
}
