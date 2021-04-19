import class Foundation.JSONEncoder
import Tracing
import WebFramework

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
struct ItemsController: Controller {
    private let jsonEncoder: JSONEncoder
    private let database: Database

    init(server: Server, database: Database, jsonEncoder: JSONEncoder) {
        self.database = database
        self.jsonEncoder = jsonEncoder

        server.get("/items", then: getItems)
        server.get("/items/:itemID", then: getItem)
    }

    private func getItems(request: Request, context: RequestContext) async throws -> Response {
        let items = try await InstrumentationSystem.tracer.withSpan("Get all items") {
            try await self.database.getItems()
        }

        return try Response(encoding: items, using: jsonEncoder, request: request, context: context)
    }

    private func getItem(request: Request, context: RequestContext) async throws -> Response {
        guard let itemID = request.parameters.get("itemID", as: Int.self) else {
            throw HTTPError(status: .badRequest)
        }

        let item: Item = try await InstrumentationSystem.tracer.withSpan("Get item by ID") {
            guard let item = try await self.database.getItem(id: itemID) else {
                throw HTTPError(status: .notFound)
            }
            return item
        }

        return try Response(encoding: item, using: jsonEncoder, request: request, context: context)
    }
}

enum CustomError: Error {
    case some
}
