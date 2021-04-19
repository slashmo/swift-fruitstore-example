import ArgumentParser

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
@main
struct Storage: ParsableCommand {
    static var configuration = CommandConfiguration(subcommands: [Serve.self])
    static let serviceName: String = "fruitstore.storage"
}
