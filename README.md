# Server-Side Swift Example: FruitStore

This repo contains an example that showcases various aspects of the Server-Side Swift ecosystem.
It's a microservices-oriented set of APIs, instrumented using [Logging](https://github.com/apple/swift-log),
[Metrics](https://github.com/apple/swift-metrics),
and [Distributed Tracing](https://github.com/apple/swift-distributed-tracing).

## Running locally

Each service is contained in its own Swift package, located under `/services/<service-name>`.

### Docker 🐳

Traces are exported to an OpenTelemetry Collector running in a Docker container, and visualized via Jaeger.
Both of these containers may be started through [`docker-compose.yaml`](docker-compose.yaml):

```bash
docker-compose up -d
```

### ⚠️ Latest Swift Toolchain

This example makes use of yet to be release Swift features such as async/await and task locals.
Therefore you'll need to have the latest development snapshot of Swift installed on a Mac.

You also need to specify the `DYLD_LIBRARY_PATH` to be able to run the executables:

```bash
export DYLD_LIBRARY_PATH=/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/lib/swift/macosx
```

To run the `Storage` service, build and execute `storagectl`:

```bash
cd services/storage
swift build && ./.build/debug/storagectl serve --log-level trace
```
