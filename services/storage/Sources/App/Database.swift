import Dispatch
import Tracing
import MongoSwift
import _MongoSwiftConcurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class Database {
    private let itemsCollection: MongoCollection<Item>

    init(mongoDatabase: MongoDatabase) {
        itemsCollection = mongoDatabase.collection("items", withType: Item.self)
    }

    func getItems() async throws -> [Item] {
        try await itemsCollection.find().toArray()
    }

    func getItem(id: Int) async throws -> Item? {
        try await itemsCollection.findOne(["id": .int64(Int64(id))])
    }

    private func simulateDelay() async {
        usleep(.random(in: 0 ..< 1_000_000))
    }
}
