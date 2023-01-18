import Vapor
import Tracing

func routes(_ app: Application) throws {
    struct Book: Codable {
        let name: String
    }
    struct Author: Codable {
        let id: Int
        let name: String
        let books: [Book]
    }

    let authors: [Author] = [
        .init(
            id: 0, name: "Eric Carle", books: [
                .init(name: "The Very Hungry Caterpillar"),
                .init(name: "Brown Bear, Brown Bear, What Do You See?"),
            ]
        ),
        .init(
            id: 1, name: "J.R.R. Tolkien", books: [
                .init(name: "The Hobbit"),
                .init(name: "The Lord of the Rings"),
            ]
        ),
        .init(
            id: 2, name: "Daniel Steinberg", books: [
                .init(name: "A Bread Baking Kickstart"),
                .init(name: "A Functional Programming Kickstart"),
                .init(name: "A SwiftUI Programming Kickstart"),
                .init(name: "A Swift Programming Kickstart"),
            ]
        ),
        .init(
            id: 3, name: "Charles Dickens", books: [
                .init(name: "A Tale of Two Cities"),
                .init(name: "A Christmas Carol"),
                .init(name: "Oliver Twist"),
            ]
        ),
        .init(
            id: 4, name: "George Orwell", books: [
                .init(name: "Animal Farm"),
                .init(name: "Nineteen Eighty-four"),
            ]
        ),
        .init(
            id: 5, name: "C.S Lewis", books: [
                .init(name: "The Lion, The Witch and the Wardrobe"),
                .init(name: "Prince Caspian: The Return to Narnia"),
            ]
        ),
    ]

    struct AuthorResponse: Content {
        let id: Int
        let name: String
    }

    struct BookResponse: Content {
        let name: String
    }

    app.get("authors") { req async throws -> [AuthorResponse] in
        var baggage = Baggage.topLevel
        InstrumentationSystem.instrument.extract(
            req.headers,
            into: &baggage,
            using: HTTPHeadersExtractor()
        )
        let span = InstrumentationSystem.tracer.startSpan("GET /authors", baggage: baggage)
        defer { span.end() }

        let fakeDatabaseCallSpan = InstrumentationSystem.tracer.startSpan("postgres.query", baggage: span.baggage)
        defer { fakeDatabaseCallSpan.end() }
        fakeDatabaseCallSpan.attributes["statement"] = "SELECT * FROM authors"

        // fake latency
        try await Task.sleep(until: .now + .milliseconds(250), clock: .continuous)

        return authors.map { AuthorResponse(id: $0.id, name: $0.name) }
    }

    struct BooksQuery: Content {
        let authorId: Int
    }
    app.get("books") { req async throws -> [BookResponse] in
    var baggage = Baggage.topLevel
        InstrumentationSystem.instrument.extract(
            req.headers,
            into: &baggage,
            using: HTTPHeadersExtractor()
        )
        let span = InstrumentationSystem.tracer.startSpan("GET /books", baggage: baggage)
        defer { span.end() }

        let booksQuery = try req.query.decode(BooksQuery.self)
        span.attributes["author_id"] = booksQuery.authorId

        let fakeDatabaseCallSpan = InstrumentationSystem.tracer.startSpan("postgres.query", baggage: span.baggage)
        defer { fakeDatabaseCallSpan.end() }
        fakeDatabaseCallSpan.attributes["statement"] = "SELECT * FROM books WHERE author_id = ?"

        // fake latency
        try await Task.sleep(until: .now + .milliseconds(250), clock: .continuous)

        guard let author = authors.filter({ $0.id == booksQuery.authorId }).first else {
            throw Abort(.notFound, reason: "Author with that ID not found")
        }

        return author.books.map { BookResponse(name: $0.name) }
    }
}

struct HTTPHeadersExtractor: Extractor {
    public init() {}

    public func extract(key: String, from carrier: HTTPHeaders) -> String? {
        let headers = carrier
            .lazy
            .filter { $0.name == key }
            .map { $0.value }
        return headers.isEmpty ? nil : headers.joined(separator: ",")
    }
}
