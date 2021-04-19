import class Foundation.JSONEncoder
import NIO
import NIOHTTP1

public struct Response {
    public var head: HTTPResponseHead
    public var body: ByteBuffer?

    public init(head: HTTPResponseHead, body: ByteBuffer? = nil) {
        self.head = head
        self.body = body
    }
}

public protocol ResponseConvertible {
    func convertToResponse(request: Request, context: RequestContext) async throws -> Response
}

extension Response: ResponseConvertible {
    public func convertToResponse(request: Request, context: RequestContext) async throws -> Response {
        self
    }
}

extension String: ResponseConvertible {
    public func convertToResponse(request: Request, context: RequestContext) async throws -> Response {
        let body = context.allocator.buffer(string: self + "\n")
        let head = HTTPResponseHead(version: request.head.version, status: .ok, headers: [
            "Content-Type": "text/plain; charset=utf-8;",
            "Content-Length": "\(body.readableBytes)",
        ])
        return Response(head: head, body: body)
    }
}

extension Response {
    public init<Model: Encodable>(
        encoding model: Model,
        using jsonEncoder: JSONEncoder,
        request: Request,
        context: RequestContext
    ) throws {
        let body = try context.allocator.buffer(bytes: jsonEncoder.encode(model))
        let head = HTTPResponseHead(version: request.head.version, status: .ok, headers: [
            "Content-Length": "\(body.readableBytes)",
            "Content-Type": "application/json; charset=utf-8;",
        ])
        self = Response(head: head, body: body)
    }
}
