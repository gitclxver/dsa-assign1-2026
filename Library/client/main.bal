import ballerina/http;
import ballerina/io;
import ballerina/uuid;

// Talks to the REST API (server must be running on port 8081).
final http:Client apiClient = check new ("http://localhost:8081/api");

// Simple admin password for demo purposes.
const string ADMIN_PASSWORD = "admin123";

// Data models

public type Component record {
    string compId;
    string name;
    string description;
};

public type Schedule record {
    string scheduleId;
    string 'type;
    string dueDate;
    string description;
};

public type Task record {
    string taskId;
    string description;
};

public type WorkOrder record {
    string orderId;
    string status;
    string description;
    Task[] tasks?;
};

public type Asset record {
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status;
    string dateAcquired;
    Component[] components?;
    Schedule[] schedules?;
    WorkOrder[] workOrders?;
};

// Main menu.

public function main() returns error? {
    io:println("Library & Resource Management CLI");

    // Auto seed data for the system.
    io:println("\nSeeding Demo Data");
    error? seedResult = seedDemoData();
    if seedResult is error {
        io:println("Seed Failed: " + seedResult.message());
    } else {
        io:println("Items Seeded Successfully!");
    }

    boolean running = true;
    while running {
        io:println("\nMAIN MENU");
        io:println("1. User CLI");
        io:println("2. Admin CLI");
        io:println("0. Exit");

        string choice = io:readln("Choice: ").trim();
        if choice == "1" {
            userMenu();
        } else if choice == "2" {
            adminMenu();
        } else if choice == "0" {
            running = false;
            io:println("Goodbye!");
        } else {
            io:println("Invalid Choice.");
        }
    }
}

// User CLI.

function userMenu() {
    boolean running = true;
    while running {
        io:println("\nUSER MENU");
        io:println("1. View All");
        io:println("2. Search");
        io:println("3. Filter (Institution / Site)");
        io:println("4. Loan / Book");
        io:println("5. Overdue List");
        io:println("0. Back");

        string choice = io:readln("Choice: ").trim();
        if choice == "0" {
            running = false;
            continue;
        }

        error? result = runUserAction(choice);
        if result is error {
            io:println("Error: " + result.message());
        }
        pause();
    }
}

function runUserAction(string choice) returns error? {
    if choice == "1" {
        return viewAllShort();
    } else if choice == "2" {
        return searchViewShort();
    } else if choice == "3" {
        return campusViewShort();
    } else if choice == "4" {
        return loanOrBook();
    } else if choice == "5" {
        return overdueDashboardShort();
    }
    io:println("Invalid Choice.");
}

// Admin CLI.

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
        io:println("1. Manual Seed Demo Data");
        io:println("2. Add New Asset");
        io:println("3. Delete Asset");
        io:println("4. View All (Full Details)");
        io:println("5. Schedule Manager");
        io:println("6. Set Status (A / U)");
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
        return seedDemoData();
    } else if choice == "2" {
        return addAssetInteractive();
    } else if choice == "3" {
        return deleteAssetInteractive();
    } else if choice == "4" {
        return viewAllFull();
    } else if choice == "5" {
        return scheduleManager();
    } else if choice == "6" {
        return toggleStatus();
    }
    io:println("Invalid Choice.");
}

// Admin add and delete helpers.

function addAssetInteractive() returns error? {
    io:println("\nAdd Asset:");
    Asset asset = {
        assetTag: io:readln("Tag: ").trim(),
        name: io:readln("Name: ").trim(),
        description: io:readln("Description: ").trim(),
        institution: io:readln("Institution: ").trim(),
        site: io:readln("Site: ").trim(),
        status: "AVAILABLE",
        dateAcquired: io:readln("Date Acquired (YYYY-MM-DD): ").trim()
    };

    http:Response res = check apiClient->post("/assets", asset);
    if res.statusCode == 201 {
        io:println("Added [" + asset.assetTag + "] " + asset.name);
    } else {
        io:println("Failed (Status " + res.statusCode.toString() + "). Tag Already Exist.");
    }
}

function deleteAssetInteractive() returns error? {
    io:println("\nDelete Asset:");
    Asset? selected = check chooseAsset();
    if selected is () {
        return;
    }
    http:Response res = check apiClient->delete("/assets/" + selected.assetTag);
    if res.statusCode >= 200 && res.statusCode < 300 {
        io:println("Deleted [" + selected.assetTag + "] " + selected.name);
    } else {
        io:println("Delete Failed (Status " + res.statusCode.toString() + ").");
    }
}

// Set status with one letter keys: a = AVAILABLE, u = UNAVAILABLE.
function toggleStatus() returns error? {
    io:println("\nSet Status:");
    Asset? selected = check chooseAsset();
    if selected is () {
        return;
    }
    Asset asset = selected;

    io:println("Asset: [" + asset.assetTag + "] " + asset.name);
    io:println("Current Status: " + asset.status);
    io:println("  A = AVAILABLE");
    io:println("  U = UNAVAILABLE");
    io:println("  0 = Cancel");

    string key = io:readln("Key: ").trim().toLowerAscii();
    if key == "0" {
        io:println("Cancelled.");
        return;
    } else if key == "a" {
        asset.status = "AVAILABLE";
    } else if key == "u" {
        asset.status = "UNAVAILABLE";
    } else {
        io:println("Unknown Key. Use A Or U.");
        return;
    }

    http:Response res = check apiClient->put("/assets/" + asset.assetTag, asset);
    if res.statusCode >= 200 && res.statusCode < 300 {
        io:println("Saved. Status Is Now " + asset.status + ".");
    } else {
        io:println("Save Failed (Status " + res.statusCode.toString() + ").");
    }
}
