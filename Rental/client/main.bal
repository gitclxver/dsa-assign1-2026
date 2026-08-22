import ballerina/grpc;
import ballerina/io;

final RentalServiceClient ep = check new ("http://localhost:9090");

// Simple admin password for demo purposes.
const string ADMIN_PASSWORD = "admin123";

// Main menu.

public function main() returns error? {
    io:println("Rental Accommodation gRPC Client (Admin Only)");

    // Auto seed demo properties before the menus.
    io:println("\nSeeding Demo Data");
    error? seedResult = seedDemo();
    if seedResult is error {
        io:println("Seed Failed: " + seedResult.message());
    } else {
        io:println("Items Seeded Successfully!");
    }

    boolean running = true;
    while running {
        io:println("\nMAIN MENU");
        io:println("1. Admin CLI");
        io:println("0. Exit");

        string choice = io:readln("Choice: ").trim();
        if choice == "1" {
            adminMenu();
        } else if choice == "0" {
            running = false;
            io:println("Goodbye!");
        } else {
            io:println("Invalid Choice.");
        }
    }
}

// Admin CLI: CRUD and seed.

function adminMenu() {
    string password = io:readln("Admin Password: ").trim();
    if password != ADMIN_PASSWORD {
        io:println("Wrong Password.");
        return;
    }
    io:println("Admin Access Granted.");

    boolean running = true;
    while running {
        io:println("\nADMIN MENU");
        io:println("1. Seed Demo Data");
        io:println("2. Add Property");
        io:println("3. Create Users");
        io:println("4. Update Property");
        io:println("5. Delete Property");
        io:println("6. List Available Properties");
        io:println("0. Back");

        string choice = io:readln("Choice: ").trim();
        if choice == "0" {
            running = false;
            continue;
        }

        error? result = runAdminAction(choice);
        if result is error {
            io:println("Error: " + result.message());
        }
        pause();
    }
}

function runAdminAction(string choice) returns error? {
    if choice == "1" {
        return seedDemo();
    } else if choice == "2" {
        return addPropertyUI();
    } else if choice == "3" {
        return createUsersUI();
    } else if choice == "4" {
        return updatePropertyUI();
    } else if choice == "5" {
        return removePropertyUI();
    } else if choice == "6" {
        return listAvailableUI();
    }
    io:println("Invalid Choice.");
}

// Admin: add property.

function addPropertyUI() returns error? {
    io:println("\nAdd Property:");
    Property property = {
        name: io:readln("Property Name: ").trim(),
        location: io:readln("Location/Region: ").trim(),
        property_type: io:readln("Type (Apartment/House/Room): ").trim(),
        price_per_night: check float:fromString(io:readln("Price Per Night: ").trim()),
        status: AVAILABLE,
        host_id: io:readln("Host Id: ").trim()
    };
    // property_id is left unset here because the server generates it and
    // returns it inside AddPropertyResponse — the client never assigns its own ID.
    AddPropertyResponse res = check ep->add_property({property: property});
    io:println("Created Property With Id: " + res.property_id);
}

// Admin: create users via client streaming.

function createUsersUI() returns error? {
    io:println("\nCreate Users:");
    // Opens a client-streaming call: the server won't send a response until
    // we explicitly call complete(), so we can push multiple users first.
    Create_usersStreamingClient sClient = check ep->create_users();
    boolean adding = true;
    while adding {
        string uid = io:readln("User Id (Blank To Finish): ").trim();
        if uid == "" {
            adding = false;
        } else {
            string name = io:readln("Name: ").trim();
            string roleStr = io:readln("Role (HOST/GUEST): ").trim().toUpperAscii();
            UserRole role = roleStr == "GUEST" ? GUEST : HOST;
            check sClient->sendUser({user_id: uid, name: name, role: role});
        }
    }
    // Signals to the server that no more users are coming, so it can
    // process the batch and send back a single summary response.
    check sClient->complete();
    CreateUsersResponse? response = check sClient->receiveCreateUsersResponse();
    if response is CreateUsersResponse {
        io:println(response.message);
    }
}

// Admin: update property.

function updatePropertyUI() returns error? {
    io:println("\nUpdate Property:");
    string id = io:readln("Property Id To Update: ").trim();
    Property property = {
        property_id: id,
        name: io:readln("New Name: ").trim(),
        location: io:readln("New Location: ").trim(),
        property_type: io:readln("New Type: ").trim(),
        price_per_night: check float:fromString(io:readln("New Price Per Night: ").trim()),
        status: io:readln("Status (AVAILABLE/UNAVAILABLE): ").trim().toUpperAscii() == "UNAVAILABLE" ? UNAVAILABLE : AVAILABLE,
        host_id: io:readln("Host Id: ").trim()
    };
    // update_property returns the updated Property directly (not wrapped in
    // a response record), so we branch on grpc:Error instead of checking a success flag.
    Property|grpc:Error updated = ep->update_property({property_id: id, property: property});
    if updated is grpc:Error {
        io:println("Error: " + updated.message());
    } else {
        io:println("Updated: " + updated.property_id + " Is Now " + updated.name);
    }
}

// Admin: delete property.

function removePropertyUI() returns error? {
    io:println("\nDelete Property:");
    string id = io:readln("Property Id To Remove: ").trim();
    PropertyList|grpc:Error result = ep->remove_property({property_id: id});
    if result is grpc:Error {
        io:println("Error: " + result.message());
    } else {
        io:println("Removed. Remaining Available In That Region:");
        foreach Property p in result.properties {
            printProperty(p);
        }
    }
}

// List available properties (admin).

function listAvailableUI() returns error? {
    io:println("\nList Available Properties:");
    string location = io:readln("Filter By Location (Blank = All): ").trim();
    // list_available_properties is server-side streaming: it returns a stream
    // immediately and results arrive one at a time as the server produces them.
    stream<Property, grpc:Error?> propStream = check ep->list_available_properties({location: location, min_price: 0.0, max_price: 0.0});
    int count = 0;
    check from Property p in propStream
        do {
            printProperty(p);
            count += 1;
        };
    io:println("Total Available: " + count.toString());
}

// Seed demo properties (startup and admin).

function seedDemo() returns error? {
    Property[] demo = [
        {name: "Seaside Villa", location: "Swakopmund", property_type: "House", price_per_night: 1200.0, status: AVAILABLE, host_id: "H1"},
        {name: "City Apartment", location: "Windhoek", property_type: "Apartment", price_per_night: 650.0, status: AVAILABLE, host_id: "H1"},
        {name: "Desert Lodge Room", location: "Sossusvlei", property_type: "Room", price_per_night: 900.0, status: AVAILABLE, host_id: "H2"}
    ];
    foreach Property p in demo {
        AddPropertyResponse res = check ep->add_property({property: p});
        io:println("  Seeded " + res.property_id + ": " + p.name);
    }
    io:println("Seed Done.");
}

function printProperty(Property p) {
    io:println(string `  [${p.property_id}] ${p.name} | ${p.location} | ${p.property_type} | $${p.price_per_night}/Night | ${p.status}`);
}

function pause() {
    _ = io:readln("\nPress Enter To Return... ");
}