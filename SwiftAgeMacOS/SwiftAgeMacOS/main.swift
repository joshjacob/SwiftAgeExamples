//
//  main.swift
//  SwiftAgeMacOS
//
//  Created by Joshua Jacob on 3/7/23.
//

import PostgresNIO
import NIOPosix
import Logging
import Antlr4
import Foundation
import SwiftAge

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let logger = Logger(label: "postgres-logger")

func setupConnection() async -> PostgresConnection? {
    
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

var connection = await setupConnection()
guard let connection = connection else { exit(1) }

print("Welcome to the SwiftAge command line tester!")

var keepLooping = true
while (keepLooping) {
    print("\nNext command:")
    let str = readLine()
    switch (str) {
        
    case "list":
        let rows = try await connection.execCypher(
            "SELECT * FROM cypher('test_graph_1', $$ MATCH (v:Person) RETURN v $$) as (v agtype);",
            logger: logger).get()
        if rows.count > 0 {
            for row in rows {
                if let vertex = row as? Vertex {
                    let name = vertex.properties["name"] ?? "missing"
                    print("Found person with name \( name ) (id = \( vertex.id ))")
                }
            }
        } else {
            print("No people present.")
        }
        
    case "add":
        print("Enter person's name:")
        let addName = readLine()
        if let addNameString = addName, addNameString != "" {
            let params: Dictionary<String,AGValue> = ["newName": addNameString]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ CREATE (:Person {name: $newName}) $$, \( paramsWrapper )) as (v agtype);",
                logger: logger).get()
            print("Person added.")
        } else {
            print("Skipping. No name entered.")
        }
        
    case "del":
        print("Enter person's id:")
        let person = readLine()
        if let personString = person, let personInt = Int64(personString) {
            let params: Dictionary<String,AGValue> = ["personId": personInt]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (a:Person) WHERE id(a) = $personId DETACH DELETE a $$, \( paramsWrapper )) as (v agtype);",
                logger: logger).get()
            print("Person deleted.")
        } else {
            print("Skipping. No name entered.")
        }
        
    case "list_rel":
        let rows = try await connection.execCypher(
            "SELECT * FROM cypher('test_graph_1', $$ MATCH (a:Person)-[r:Related_To]->(b:Person) RETURN a, b, r $$) as (a agtype, b agtype, r agtype);",
            logger: logger).get()
        if rows.count > 0 {
            for row in rows {
                if let values = row as? [AGValue],
                   let vertex1 = values[0] as? Vertex,
                   let vertex2 = values[1] as? Vertex,
                   let e = values[2] as? Edge {
                    let name1 = vertex1.properties["name"] ?? "missing"
                    let name2 = vertex2.properties["name"] ?? "missing"
                    print("Found \( name1 ) related to \( name2 ) with relation id \(e.id)")
                }
            }
        } else {
            print("No people present.")
        }
        
    case "add_rel":
        print("Enter person 1's id:")
        let person1 = readLine()
        print("Enter person 2's id:")
        let person2 = readLine()
        if let person1String = person1, let person1Int = Int64(person1String),
            let person2String = person2, let person2Int = Int64(person2String) {
            let params: Dictionary<String,AGValue> = ["person1": person1Int, "person2": person2Int]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (a:Person), (b:Person) WHERE id(a) = $person1 AND id(b) = $person2 CREATE (a)-[e:Related_To]->(b) RETURN e $$, \( paramsWrapper )) as (e agtype);",
                logger: logger).get()
            print("Relation added.")
        } else {
            print("Skipping. No names entered.")
        }
        
    case "del_rel":
        print("Enter relation id:")
        let rel = readLine()
        if let relString = rel, let relInt = Int64(relString) {
            let params: Dictionary<String,AGValue> = ["rel": relInt]
            let paramsWrapper: AGValueWrapper = AGValueWrapper(value: params)
            let _ = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (:Person)-[e:Related_To]->(:Person) WHERE id(e) = $rel DELETE e $$, \( paramsWrapper )) as (e agtype);",
                logger: logger).get()
            print("Relation removed.")
        } else {
            print("Skipping. No names entered.")
        }
        
    case "quit":
        print("Goodbye!")
        keepLooping = false
        break
        
    // case "help":
    default:
        print("  Commands:")
        print("    list - list all 'Person' vertexes in the graph")
        print("    add  - add 'Person' vertex")
        print("    del  - delete 'Person' vertex")
        print("    list_rel - list all 'Person' to 'Person' relations")
        print("    add_rel - add a 'Person' to 'Person' relation")
        print("    del_rel - delete a 'Person' to 'Person' relation")
        print("    quit - say goodbye")
    }
}
    
// Close your connection once done
let _ = connection.close()

// Shutdown the EventLoopGroup, once all connections are closed.
try await eventLoopGroup.shutdownGracefully()

