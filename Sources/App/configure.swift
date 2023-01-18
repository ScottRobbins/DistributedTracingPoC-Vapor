import Vapor
import NIO
import OpenTelemetry
import Tracing
import OtlpGRPCSpanExporting

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let exporter = OtlpGRPCSpanExporter(
            config: OtlpGRPCSpanExporter.Config(
                eventLoopGroup: group,
                host: "host.docker.internal"
            )
        )
    let processor = OTel.SimpleSpanProcessor(exportingTo: exporter)
    let otel = OTel(serviceName: "distributed-tracing-poc-server", eventLoopGroup: group, processor: processor)

    try otel.start().wait()
    InstrumentationSystem.bootstrap(otel.tracer())

    // register routes
    try routes(app)
}
