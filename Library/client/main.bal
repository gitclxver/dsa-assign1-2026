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