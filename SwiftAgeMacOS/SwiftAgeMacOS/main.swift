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

let connection = try await PostgresConnection.connect(
  on: eventLoopGroup.next(),
  configuration: config,
  id: 1,
  logger: logger
).get()

let _ = try await connection.query("LOAD 'age';", logger: logger).get()
let _ = try await connection.query("SET search_path = ag_catalog, \"$user\", public;", logger: logger).get()

do {
    let rows = try await connection.query(
        "SELECT * FROM cypher('test_graph_1', $$ MATCH (v:Person) RETURN v $$) as (v agtype);",
        logger: logger).get()
    if rows.count > 0 {
        for row in rows {
            let cell : PostgresCell? = row.first
            var byteBuffer = cell?.bytes
            let jsonBVersionBytes: [UInt8] = [0x01]
            let _ = byteBuffer?.readBytes(length: jsonBVersionBytes.count)
            let readableBytes = byteBuffer?.readableBytes ?? 0
            let data = Data((byteBuffer?.readBytes(length: readableBytes))!)
            let string = String.init(data: data, encoding: .utf8)
            
            let parsed = try SwiftAgeParser.parse(input: string!)
            print(parsed as Any)
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

// Close your connection once done
let _ = connection.close()

// Shutdown the EventLoopGroup, once all connections are closed.
try eventLoopGroup.syncShutdownGracefully()

