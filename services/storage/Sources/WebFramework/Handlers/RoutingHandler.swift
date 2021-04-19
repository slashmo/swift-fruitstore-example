import CoreBaggage
import NIO
import NIOHTTP1
import RoutingKit
import Tracing
import TracingOpenTelemetrySupport

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class RoutingHandler: ChannelInboundHandler {
    typealias InboundIn = Request
    typealias OutboundOut = Response

    private let router: TrieRouter<Route>

    init(router: TrieRouter<Route>) {
        self.router = router
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var request = unwrapInboundIn(data)
        let requestContext = RequestContext(eventLoop: context.eventLoop, allocator: context.channel.allocator)
        let path = Array(request.head.uri.components(separatedBy: "/").dropFirst())
        var baggage = Baggage.topLevel
        InstrumentationSystem.instrument.extract(request.head.headers, into: &baggage, using: HTTPHeadersExtractor())

        guard let route = router.route(path: path, parameters: &request.parameters) else {
            respond(with: HTTPError(status: .notFound), to: request, baggage: baggage, context: context)
            return
        }

        guard route.method == request.head.method else {
            respond(with: HTTPError(status: .methodNotAllowed), to: request, baggage: baggage, context: context)
            return
        }

        detach { [weak self, request] in
            guard let self = self else { return }
            let routeString = "/\(route.path.string)"
            await InstrumentationSystem.tracer.withSpan(routeString, ofKind: .server, at: request.timestamp) { span in
                span.attributes.http.method = request.head.method.rawValue
                span.attributes.http.flavor = "\(request.head.version.major).\(request.head.version.minor)"
                span.attributes.http.requestContentLength = request.body?.readableBytes
                span.attributes.http.server.route = routeString
                span.attributes.http.target = request.head.uri
                do {
                    let response = try await route
                        .handler(request, requestContext)
                        .convertToResponse(request: request, context: requestContext)
                    span.attributes.http.responseContentLength = response.body?.readableBytes
                    span.attributes.http.statusCode = Int(response.head.status.code)
                    context.eventLoop.execute {
                        context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
                    }
                } catch let error as HTTPError {
                    span.recordError(error)
                    span.setStatus(SpanStatus(code: .error))
                    span.attributes.http.statusCode = Int(error.status.code)
                    let head = HTTPResponseHead(version: request.head.version, status: error.status)
                    let response = self.wrapOutboundOut(Response(head: head, body: nil))
                    context.eventLoop.execute {
                        context.writeAndFlush(response, promise: nil)
                    }
                } catch {
                    span.recordError(error)
                    span.setStatus(SpanStatus(code: .error, message: "\(error)"))
                    span.attributes.http.statusCode = Int(HTTPResponseStatus.internalServerError.code)
                    let head = HTTPResponseHead(version: request.head.version, status: .internalServerError)
                    let response = self.wrapOutboundOut(Response(head: head, body: nil))
                    context.eventLoop.execute {
                        context.writeAndFlush(response, promise: nil)
                    }
                }
            }
        }
    }

    private func respond(with httpError: HTTPError, to request: Request, baggage: Baggage, context: ChannelHandlerContext) {
        let span = InstrumentationSystem.tracer.startSpan(
            request.head.uri,
            baggage: baggage,
            ofKind: .server,
            at: request.timestamp
        )
        defer {
            span.end()
        }
        span.attributes.http.method = request.head.method.rawValue
        span.attributes.http.flavor = "\(request.head.version.major).\(request.head.version.minor)"
        span.attributes.http.requestContentLength = request.body?.readableBytes
        span.attributes.http.target = request.head.uri
        span.attributes.http.statusCode = Int(httpError.status.code)
        span.recordError(HTTPError(status: httpError.status))
        span.setStatus(SpanStatus(code: .error))
        let head = HTTPResponseHead(version: request.head.version, status: httpError.status)
        let response = wrapOutboundOut(Response(head: head, body: nil))
        context.eventLoop.execute {
            context.writeAndFlush(response, promise: nil)
        }
        return
    }
}

final class Route {
    let path: [PathComponent]
    let method: HTTPMethod
    let handler: Handler

    init(path: [PathComponent], method: HTTPMethod, handler: @escaping Handler) {
        self.path = path
        self.method = method
        self.handler = handler
    }
}

public typealias Handler = (Request, RequestContext) async throws -> ResponseConvertible

struct HTTPHeadersExtractor: Extractor {
    func extract(key name: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: name)
    }
}
