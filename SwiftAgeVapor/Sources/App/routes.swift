import Vapor

func routes(_ app: Application) throws {
    
    try app.register(collection: SwiftAgeTestController())
    
    app.get { req async throws in
        try await req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
}
