import Logging
import NIO
import NIOHTTP1
import _NIOConcurrency
import RoutingKit

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public final class Server {
    private let host: String
    private let port: Int
    private let router = TrieRouter<Route>()

    private let group: EventLoopGroup
    private let logger: Logger
    private weak var listener: Channel?

    public init(host: String, port: Int, eventLoopGroup: EventLoopGroup, logger: Logger) {
        self.host = host
        self.port = port
        self.group = eventLoopGroup
        self.logger = logger
    }

    public func start() async throws {
        let channel = try await ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { childChannel in
                childChannel.pipeline.configureHTTPServerPipeline().flatMap {
                    childChannel.pipeline.addHandlers([
                        HTTPHandler(),
                        RoutingHandler(router: self.router),
                    ])
                }
            }
            .bind(host: host, port: port)
            .get()
        guard let address = channel.localAddress else { return }
        logger.notice("Server listening", metadata: ["address": .stringConvertible(address)])
        listener = channel
    }

    public func shutdown() async throws {
        try await (listener?.close() ?? group.next().makeSucceededVoidFuture()).get()
    }

    public func get(_ path: String, then handle: @escaping Handler) {
        let route = Route(path: path.pathComponents, method: .GET, handler: handle)
        router.register(route, at: path.pathComponents)
    }
}
