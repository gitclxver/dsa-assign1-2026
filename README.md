DSA Assignment 1

Two systems in Ballerina. Data is in memory so you only need Ballerina.

Library-Management
REST API on port 8081 plus a CLI client.
cd Library-Management/server
bal run
Then in another terminal:
cd Library-Management/client
bal run

Rental-Accommodation
gRPC service on port 9090 plus a CLI client.
cd Rental-Accommodation/server
bal run
Then in another terminal:
cd Rental-Accommodation/client
bal run
User CLI: list, search, book, confirm.
Admin CLI (password admin123): seed, add, create users, update, delete.

Install Ballerina 2201.12.9 from https://ballerina.io/downloads/
Check with: bal version

Library REST base URL: http://localhost:8081/api
Assets: POST GET PUT DELETE /assets
Also: /assets/overdue, /assets/institution/{name}, /assets/site/{name}
Schedules and components under /assets/{tag}/...

Rental RPCs:
add_property, create_users, update_property, remove_property
list_available_properties, search_property, book_property, confirm_booking

Notes:
Restarting a server clears data.
Keep ports 8081 and 9090 free.
See SETUP.md for more run steps.
