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
    case "help":
        print("  Commands:")
        print("    list - list all 'Person' vertexes in the graph")
        print("    quit - say goodbye")
    case "list":
        do {
            let rows = try await connection.execCypher(
                "SELECT * FROM cypher('test_graph_1', $$ MATCH (v:Person) RETURN v $$) as (v agtype);", logger: logger).get()
            if rows.count > 0 {
                for row in rows {
                    if let vertex = row as? Vertex {
                        print("Found person with name \( (vertex.properties as? Dictionary<String,AGValue>)?["name"] ?? "missing" )")
                    }
                }
            } else {
                print("No test data present. Inserting...")
                let insert = try await connection.query("""
SELECT *
FROM cypher('test_graph_1', $$
CREATE (:Person {name: 'John'}),
       (:Person {name: 'Jeff'}),
       (:Person {name: 'Joan'}),
       (:Person {name: 'Bill'})
$$) AS (result agtype);
""",
                                                        logger: logger).get()
                print("Test data inserted. Please run again.")
            }
            
        } catch (let e) {
            print(e)
        }
    case "add":
        print("Enter person's name:")
        let addName = readLine()
        if let addNameString = addName, addNameString != "" {
            var params = Dictionary<String,String>()
            params["newName"] = addNameString
//            let paramJson = String(data: try JSONEncoder().encode(params), encoding: .utf8) ?? ""
            let query = PostgresQuery("""
                SELECT * FROM cypher('test_graph_1', $$ CREATE (:Person {name: $newName}) $$, \( addNameString )) as (v agtype);
                """)
            
//            let paramJson = "{\"name\":\"Josh1\"}"
//            var bindings = PostgresBindings.init()
//            bindings.append(params as PostgresNonThrowingEncodable, context: PostgresEncodingContext.init(jsonEncoder: Foundation.JSONEncoder))
//            let query = PostgresQuery(unsafeSQL: """
//                SELECT * FROM cypher('test_graph_1', $$ CREATE (:Person {name: $newName}) $$, $1) as (v agtype);
//                """, binds: bindings)
            
            print(query.sql)
            print(query.binds)
            let _ = try await connection.execCypher(query, logger: logger).get()
        } else {
            print("Skipping. No name entered.")
        }
        
    case "test":
        var name = "test_graph_1"
        let query = PostgresQuery("SELECT count(*) FROM ag_graph WHERE name=\( name );")
        print(query.sql)
        print(query.binds)
        let agRows = try await connection.query(query, logger: logger).collect()
        print(agRows.first as Any)
        
    case "quit":
        print("Goodbye!")
        keepLooping = false
        break
        
    default:
        print("Unknown command")
    }
}
    
// Close your connection once done
let _ = connection.close()

// Shutdown the EventLoopGroup, once all connections are closed.
try eventLoopGroup.syncShutdownGracefully()

