//
//  SwiftAgeTestController.swift
//  
//
//  Created by Joshua S Jacob on 4/9/23.
//

import Vapor
import PostgresNIO
import SwiftAge

//
// Model - A simple model to represent our graph
//

public struct Person: Content {
    let id: Int64
    let name: String
    init(from vertex: Vertex) {
        id = vertex.id
        name = vertex.properties["name"] as? String ?? "<Missing>"
    }
}

public struct Relation: Content {
    let from: Person
    let to: Person
    let relationId: Int64
}

//
// Routes
//

struct SwiftAgeTestController: RouteCollection {
    
    let logger = Logger(label: "SwiftAgeTestController")

    // Demo-quality func to make connection and set up AGE.
    func setupConnection(eventLoopGroup: EventLoopGroup, logger: Logger) async -> PostgresConnection? {

        let config = PostgresConnection.Configuration(
            connection: .init(
                host: "localhost",
                port: 5455
            ),
            authentication: .init(
                username: "postgresUser",
                database: "postgresDB",
                password: "postgresPW"
            ),
            tls: .disable
        )

        do {
            let connection = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: config,
                id: 1,
                logger: logger
            ).get()
            
            let _ = try await connection.setUpAge(logger: logger).get()
            
            return connection
        } catch {
            print("Error connecting to DB: \(error.localizedDescription)")
        }
        return nil
    }
    
    func boot(routes: RoutesBuilder) throws {
        let person = routes.grouped("person")
        person.get(use: getPerson)
        person.post(use: postPerson)
        person.delete(":personId", use: deletePerson)
        person.group("relation") { relation in
            relation.get(use: getRelation)
            relation.post(":personId", use: postRelation)
            relation.delete(":relationId", use: deleteRelation)
        }
    }
    
    // GET /person/
    func getPerson(req: Request) async throws -> [Person] {
        var persons = [Person]()
        if let connection = await setupConnection(eventLoopGroup: req.eventLoop, logger: logger) {
            let rows = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (v:Person) RETURN v $$) as (v agtype);",
                logger: logger).get()
            for row in rows {
                if let vertex = row as? Vertex {
                    persons.append(Person(from: vertex))
                }
            }
            try await connection.close()
        }
        return persons
    }
    
    // POST /person/
    func postPerson(req: Request) async throws -> String {
        
        struct postPersonContent: Content {
            let name: String
        }
        
        let addNameString = try req.content.decode(postPersonContent.self)
        if let connection = await setupConnection(eventLoopGroup: req.eventLoop, logger: logger) {
            let params: Dictionary<String,AGValue> = ["newName": addNameString.name]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ CREATE (:Person {name: $newName}) $$, \( paramsWrapper )) as (v agtype);",
                logger: logger).get()
            try await connection.close()
            return "OK"
        }
        throw Abort(.internalServerError)
    }
    
    // DELETE /person/:personId
    func deletePerson(req: Request) async throws -> String {
        let personId = try req.parameters.require("personId")
        if let personIdInt = Int64(personId),
            let connection = await setupConnection(eventLoopGroup: req.eventLoop, logger: logger) {
            let params: Dictionary<String,AGValue> = ["personId": personIdInt]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (a:Person) WHERE id(a) = $personId DETACH DELETE a $$, \( paramsWrapper )) as (v agtype);",
                logger: logger).get()
            try await connection.close()
            return "OK"
        }
        throw Abort(.internalServerError)
    }
    
    // GET /person/relation
    func getRelation(req: Request) async throws -> [Relation] {
        var relations = [Relation]()
        if let connection = await setupConnection(eventLoopGroup: req.eventLoop, logger: logger) {
            let rows = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (a:Person)-[r:Related_To]->(b:Person) RETURN a, b, r $$) as (a agtype, b agtype, r agtype);",
                logger: logger).get()
            for row in rows {
                if let values = row as? [AGValue],
                   let vertex1 = values[0] as? Vertex,
                   let vertex2 = values[1] as? Vertex,
                   let e = values[2] as? Edge {
                    relations.append(Relation.init(from: Person(from: vertex1), to: Person(from: vertex2), relationId: e.id))
                }
            }
            try await connection.close()
        }
        return relations
    }

    // POST /person/relation/:personId
    func postRelation(req: Request) async throws -> String {
        
        struct postRelationsContent: Content {
            let to: Int64
        }
        
        let personIdString = try req.parameters.require("personId")
        let addRelationsInt = try req.content.decode(postRelationsContent.self)
        if let personId: Int64 = Int64.init(personIdString),
           let connection = await setupConnection(eventLoopGroup: req.eventLoop, logger: logger) {
            let params: Dictionary<String,AGValue> = ["person1": personId, "person2": addRelationsInt.to]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (a:Person), (b:Person) WHERE id(a) = $person1 AND id(b) = $person2 CREATE (a)-[e:Related_To]->(b) RETURN e $$, \( paramsWrapper )) as (e agtype);",
                logger: logger).get()
            try await connection.close()
            return "OK"
        }
        throw Abort(.internalServerError)
    }
    
    // DELETE /person/relation/:relationId
    func deleteRelation(req: Request) async throws -> String {
        let relationId = try req.parameters.require("relationId")
        if let relationIdInt = Int64(relationId),
            let connection = await setupConnection(eventLoopGroup: req.eventLoop, logger: logger) {
            let params: Dictionary<String,AGValue> = ["relationId": relationIdInt]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (:Person)-[e:Related_To]->(:Person) WHERE id(e) = $relationId DELETE e $$, \( paramsWrapper )) as (e agtype);",
                logger: logger).get()
            try await connection.close()
            return "OK"
        }
        throw Abort(.internalServerError)
    }
}
