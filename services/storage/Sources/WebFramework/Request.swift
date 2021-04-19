import Dispatch
import NIO
import NIOHTTP1
import RoutingKit

public struct Request {
    public var head: HTTPRequestHead
    public internal(set) var parameters = Parameters()
    public var body: ByteBuffer?
    public let timestamp: DispatchWallTime

    init(head: HTTPRequestHead, timestamp: DispatchWallTime) {
        self.head = head
        self.timestamp = timestamp
    }
}

public final class RequestContext {
    public let eventLoop: EventLoop
    public let allocator: ByteBufferAllocator

    init(eventLoop: EventLoop, allocator: ByteBufferAllocator) {
        self.eventLoop = eventLoop
        self.allocator = allocator
    }
}
