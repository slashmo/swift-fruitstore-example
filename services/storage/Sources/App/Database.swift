import Dispatch
import Tracing

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class Database {
    private let items = [
        1: "Item 1",
        2: "Item 2",
        3: "Item 3",
    ]

    func getItems() async throws -> [Item] {
        await InstrumentationSystem.tracer.withSpan("SELECT storage.items") {
            await simulateDelay()
            return items.map(Item.init)
        }
    }

    func getItem(id: Int) async throws -> Item? {
        await InstrumentationSystem.tracer.withSpan("SELECT storage.items") {
            await simulateDelay()
            return items[id].map { Item(id: id, name: $0) }
        }
    }

    private func simulateDelay() async {
        usleep(.random(in: 0 ..< 1_000_000))
    }
}
