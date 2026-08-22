DSA Assignment 1 Setup

You only need Ballerina. Data is stored in memory (no database, no Docker).

Folders:
Library-Management = REST API + CLI (port 8081)
Rental-Accommodation = gRPC + CLI (port 9090)

Install Ballerina 2201.12.9 from https://ballerina.io/downloads/
Then check:
bal version

Run every command from inside the package folder.


Question 1 Library Management

Terminal 1:
cd Library-Management/server
bal run

Terminal 2:
cd Library-Management/client
bal run

The client seeds data on startup. Use User CLI or Admin CLI (password admin123).


Question 2 Rental Accommodation

Terminal 1:
cd Rental-Accommodation/server
bal run

Terminal 2:
cd Rental-Accommodation/client
bal run

The client seeds data on startup.
User CLI: list, search, book, confirm.
Admin CLI (password admin123): seed, add, create users, update, delete.

Only if you edit the proto, regenerate stubs:
cd Rental-Accommodation
bal grpc --input proto/rental.proto --output server
bal grpc --input proto/rental.proto --output client


Ports
8081 Library REST
9090 Rental gRPC

If bal is not found, reopen the terminal.
If the port is in use, stop the other process.
Restarting a server clears all data (in memory).
