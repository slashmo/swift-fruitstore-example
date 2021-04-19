import class Foundation.JSONEncoder
import Logging
import NIO
import WebFramework
import MongoSwift
import _Concurrency

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public final class AppService {
    private let server: Server
    private lazy var jsonEncoder = JSONEncoder()
    private var controllers = [Controller]()

    private let database: Database

    public init(eventLoopGroup: EventLoopGroup, logger: Logger, mongoDatabase: MongoDatabase) {
        server = Server(host: "localhost", port: 8080, eventLoopGroup: eventLoopGroup, logger: logger)
        database = Database(mongoDatabase: mongoDatabase)
        controllers.append(ItemsController(server: server, database: database, jsonEncoder: jsonEncoder))
    }

    public func start() async throws {
        try await server.start()
    }

    public func shutdown() async throws {
        try await server.shutdown()
    }
}

protocol Controller {}
