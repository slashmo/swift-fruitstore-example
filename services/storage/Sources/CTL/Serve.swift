import App
import ArgumentParser
import Lifecycle
import LifecycleNIOCompat
import Logging
import Instrumentation
import MongoSwift
import _MongoSwiftConcurrency
import NIO
import OpenTelemetry
import OtlpGRPCSpanExporting

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
struct Serve: ParsableCommand {
    @Option
    private var logLevel = Logger.Level.info

    func run() async throws {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = logLevel
            return handler
        }

        let logger = Logger(label: Storage.serviceName)
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let lifecycle = ServiceLifecycle(configuration: ServiceLifecycle.Configuration(logger: logger))

        lifecycle.registerShutdown(label: "eventLoopGroup", .async(eventLoopGroup.shutdownGracefully))

        let mongoClient = try MongoClient(using: eventLoopGroup)
        let mongoDatabase = mongoClient.db("storage")
        lifecycle.registerShutdown(label: "mongodb", .eventLoopFuture {
            mongoClient.close().always { _ in
                cleanupMongoSwift()
            }
        })

        let otel = OTel(
            serviceName: Storage.serviceName,
            eventLoopGroup: eventLoopGroup,
            processor: OTel.BatchSpanProcessor(
                exportingTo: OtlpGRPCSpanExporter(config: .init(eventLoopGroup: eventLoopGroup, logger: logger)),
                eventLoopGroup: eventLoopGroup
            ),
            logger: logger
        )
        func startOTel() -> EventLoopFuture<Void> {
            otel.start().always { _ in
                InstrumentationSystem.bootstrap(otel.tracer())
            }
        }
        lifecycle.register(label: "otel", start: .eventLoopFuture(startOTel), shutdown: .eventLoopFuture(otel.shutdown))

        let appService = AppService(eventLoopGroup: eventLoopGroup, logger: logger, mongoDatabase: mongoDatabase)
        lifecycle.register(label: "app", start: .async(appService.start), shutdown: .async(appService.shutdown))

        lifecycle.start { error in
            if let error = error {
                Self.exit(withError: error)
            }
        }
        lifecycle.wait()
    }
}

extension Logger.Level: ExpressibleByArgument {
    public static var allValueStrings: [String] {
        Logger.Level.allCases.map(\.rawValue)
    }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension LifecycleHandler {
    static func async(_ handler: @escaping () async throws -> Void) -> Self {
        LifecycleHandler { callback in
            detach {
                do {
                    try await handler()
                    callback(nil)
                } catch {
                    callback(error)
                }
            }
        }
    }
}
