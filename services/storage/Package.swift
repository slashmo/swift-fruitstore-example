// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "storage",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .executable(name: "storagectl", targets: ["CTL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .branch("async")),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "1.0.0-alpha.7"),
        .package(url: "https://github.com/apple/swift-nio.git", .revision("f6936ae8132e14c64ed971764065e6842358fde0")),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", .branch("async")),
        .package(url: "https://github.com/slashmo/opentelemetry-swift.git", .branch("main")),
        .package(url: "https://github.com/slashmo/mongo-swift-driver.git", .branch("tracing")),
    ],
    targets: [
        .executableTarget(
            name: "CTL",
            dependencies: [
                .target(name: "App"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Lifecycle", package: "swift-service-lifecycle"),
                .product(name: "LifecycleNIOCompat", package: "swift-service-lifecycle"),
                .product(name: "OpenTelemetry", package: "opentelemetry-swift"),
                .product(name: "OtlpGRPCSpanExporting", package: "opentelemetry-swift"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend", "-enable-experimental-concurrency",
                ])
            ]
        ),
        .target(name: "App", dependencies: [
            .target(name: "WebFramework"),
            .product(name: "MongoSwift", package: "mongo-swift-driver"),
            .product(name: "_MongoSwiftConcurrency", package: "mongo-swift-driver"),
        ]),
        .target(
            name: "WebFramework",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "_NIOConcurrency", package: "swift-nio"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "TracingOpenTelemetrySupport", package: "swift-distributed-tracing"),
                .target(name: "RoutingKit"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend", "-enable-experimental-concurrency",
                ])
            ]
        ),
        // TODO: Include via Swift Package Manager once Xcode is able to resolve it
        .target(name: "RoutingKit"),
    ]
)
