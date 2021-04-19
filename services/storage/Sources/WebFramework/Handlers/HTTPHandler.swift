import NIO
import NIOHTTP1

final class HTTPHandler: ChannelDuplexHandler {
    typealias OutboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    typealias InboundIn = Response
    typealias InboundOut = Request

    private var request: Request?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapOutboundIn(data)
        switch part {
        case .head(let head):
            request = Request(head: head, timestamp: .now())
        case .body(let byteBuffer):
            request?.body = byteBuffer
        case .end(let trailers):
            if let t = trailers {
                request?.head.headers.add(contentsOf: t)
            }
            guard let r = request else { return }
            context.fireChannelRead(wrapInboundOut(r))
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = unwrapInboundIn(data)
        context.write(wrapOutboundOut(.head(response.head)), promise: nil)
        if let byteBuffer = response.body {
            context.write(wrapOutboundOut(.body(.byteBuffer(byteBuffer))), promise: nil)
        }
        context.write(wrapOutboundOut(.end(nil))).flatMap { [weak self] _ in
            guard let r = self?.request, !r.head.isKeepAlive else {
                return context.eventLoop.makeSucceededVoidFuture()
            }
            return context.close()
        }
        .cascade(to: promise)
    }
}
