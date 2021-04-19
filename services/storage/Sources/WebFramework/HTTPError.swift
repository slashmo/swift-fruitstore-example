import NIOHTTP1

public struct HTTPError: Error {
    public let status: HTTPResponseStatus

    public init(status: HTTPResponseStatus) {
        self.status = status
    }
}
