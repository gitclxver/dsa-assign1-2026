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

// Admin schedule manager. Schedule IDs are auto generated.

function scheduleManager() returns error? {
    io:println("\nSchedule Manager:");
    Asset? selected = check chooseAsset();
    if selected is () {
        return;
    }
    string tag = selected.assetTag;

    // Show existing schedules with IDs so admin can remove them easily.
    Schedule[] existing = selected.schedules ?: [];
    if existing.length() > 0 {
        io:println("Existing Schedules:");
        foreach Schedule s in existing {
            io:println("  [" + s.scheduleId + "] " + s.'type + " Due " + s.dueDate + ": " + s.description);
        }
    } else {
        io:println("No Schedules On This Asset Yet.");
    }

    io:println("\n1. Add Schedule");
    io:println("2. Remove Schedule");
    string sub = io:readln("Choice: ").trim();

    if sub == "1" {
        // Auto generate a short unique ID and show it.
        string sid = "SCH" + uuid:createType1AsString().substring(0, 8).toUpperAscii();
        Schedule schedule = {
            scheduleId: sid,
            'type: io:readln("Type (MAINTENANCE / BOOKING): ").trim(),
            dueDate: io:readln("Due Date (YYYY-MM-DD): ").trim(),
            description: io:readln("Description: ").trim()
        };
        http:Response res = check apiClient->post("/assets/" + tag + "/schedules", schedule);
        if res.statusCode >= 200 && res.statusCode < 300 {
            io:println("Schedule Added. ID: " + sid);
        } else {
            io:println("Add Failed (Status " + res.statusCode.toString() + ").");
        }
    } else if sub == "2" {
        string sid = io:readln("Schedule ID To Remove: ").trim();
        http:Response res = check apiClient->delete("/assets/" + tag + "/schedules/" + sid);
        if res.statusCode >= 200 && res.statusCode < 300 {
            io:println("Removed Schedule " + sid);
        } else {
            io:println("Remove Failed (Status " + res.statusCode.toString() + ").");
        }
    } else {
        io:println("Invalid Option.");
    }
}

// Search helpers.

function searchAssets(string query) returns Asset[]|error {
    Asset[] all = check apiClient->get("/assets");
    string q = query.toLowerAscii().trim();
    Asset[] matches = [];
    foreach Asset a in all {
        if a.assetTag.toLowerAscii().includes(q) || a.name.toLowerAscii().includes(q) {
            matches.push(a);
        }
    }
    return matches;
}

// Pick an asset by partial name or tag. One match auto selects.
function chooseAsset() returns Asset?|error {
    string query = io:readln("Search Name/Tag (Blank = All): ").trim();
    Asset[] matches = check searchAssets(query);

    if matches.length() == 0 {
        io:println("No Matches.");
        return ();
    }
    if matches.length() == 1 {
        Asset only = matches[0];
        io:println("Selected: [" + only.assetTag + "] " + only.name);
        return only;
    }

    io:println("Matches:");
    int i = 1;
    foreach Asset a in matches {
        io:println("  " + i.toString() + ". [" + a.assetTag + "] " + a.name + " (" + a.status + ")");
        i += 1;
    }
    string pick = io:readln("Number (0 = Cancel): ").trim();
    int|error index = int:fromString(pick);
    if index is error || index < 1 || index > matches.length() {
        io:println("Cancelled.");
        return ();
    }
    return matches[index - 1];
}

// User views (short).

function viewAllShort() returns error? {
    Asset[] assets = check apiClient->get("/assets");
    io:println("\n" + assets.length().toString() + " Asset(s):");
    foreach Asset a in assets {
        printShort(a);
    }
}

function searchViewShort() returns error? {
    Asset? found = check chooseAsset();
    if found is Asset {
        printShort(found);
    }
}

function campusViewShort() returns error? {
    io:println("1. Institution");
    io:println("2. Site");
    string sub = io:readln("Choice: ").trim();
    if sub == "1" {
        string inst = io:readln("Institution: ").trim();
        Asset[] assets = check apiClient->get("/assets/institution/" + inst);
        foreach Asset a in assets {
            printShort(a);
        }
    } else if sub == "2" {
        string site = io:readln("Site: ").trim();
        Asset[] assets = check apiClient->get("/assets/site/" + site);
        foreach Asset a in assets {
            printShort(a);
        }
    } else {
        io:println("Invalid Option.");
    }
}

function loanOrBook() returns error? {
    io:println("\nLoan / Book:");
    Asset? selected = check chooseAsset();
    if selected is () {
        return;
    }
    Asset asset = selected;

    if asset.status != "AVAILABLE" {
        io:println("Not Available (" + asset.status + ").");
        return;
    }

    string lname = asset.name.toLowerAscii();
    string newStatus = (lname.includes("room") || lname.includes("lab")) ? "OCCUPIED" : "LOANED_OUT";
    asset.status = newStatus;

    http:Response res = check apiClient->put("/assets/" + asset.assetTag, asset);
    if res.statusCode >= 200 && res.statusCode < 300 {
        io:println("Done. " + asset.name + " Is Now " + newStatus);
    } else {
        io:println("Failed (Status " + res.statusCode.toString() + ").");
    }
}

// Short overdue list. Shows schedule IDs so users can refer to them.
function overdueDashboardShort() returns error? {
    Asset[] assets = check apiClient->get("/assets/overdue");
    io:println("\nOverdue (" + assets.length().toString() + "):");
    if assets.length() == 0 {
        io:println("  None.");
        return;
    }
    foreach Asset a in assets {
        printShort(a);
        Schedule[] schedules = a.schedules ?: [];
        foreach Schedule s in schedules {
            io:println("      ID " + s.scheduleId + " | Due " + s.dueDate);
        }
    }
}

// Admin views (full).

function viewAllFull() returns error? {
    Asset[] assets = check apiClient->get("/assets");
    io:println("\n" + assets.length().toString() + " Asset(s) [Full]:");
    foreach Asset a in assets {
        printFull(a);
        io:println("");
    }
}

// Seed data (admin and auto on startup).

function seedDemoData() returns error? {
    Asset[] demo = [
        {
            assetTag: "NUST-LIB-3DP-001",
            name: "Pro Series 3D Printer",
            description: "High Precision Laboratory Printer.",
            institution: "Namibia University Of Science And Technology",
            site: "Main Campus Innovation Lab",
            status: "AVAILABLE",
            dateAcquired: "2024-03-10"
        },
        {
            assetTag: "NUST-LIB-LAP-002",
            name: "Dell Latitude Laptop",
            description: "Loanable Student Laptop.",
            institution: "Namibia University Of Science And Technology",
            site: "Main Campus Library",
            status: "AVAILABLE",
            dateAcquired: "2023-08-01"
        },
        {
            assetTag: "UNAM-ROOM-LAB-001",
            name: "Computer Lab A",
            description: "Bookable Computer Lab (30 Seats).",
            institution: "University Of Namibia",
            site: "Windhoek Campus",
            status: "AVAILABLE",
            dateAcquired: "2022-01-15"
        },
        {
            assetTag: "NUST-LIB-PROJ-003",
            name: "Epson Projector",
            description: "Portable Projector For Lecture Rooms.",
            institution: "Namibia University Of Science And Technology",
            site: "Main Campus Library",
            status: "AVAILABLE",
            dateAcquired: "2023-02-20"
        },
        {
            assetTag: "UNAM-LIB-BOOK-004",
            name: "Reference Encyclopedia Set",
            description: "Non Loanable Reference Material.",
            institution: "University Of Namibia",
            site: "Windhoek Campus Library",
            status: "LOANED_OUT",
            dateAcquired: "2021-11-05"
        },
        {
            assetTag: "NUST-ENG-OSC-005",
            name: "Digital Oscilloscope",
            description: "Electronics Lab Measuring Device.",
            institution: "Namibia University Of Science And Technology",
            site: "Engineering Campus Lab 2",
            status: "AVAILABLE",
            dateAcquired: "2024-06-18"
        }
    ];

    foreach Asset asset in demo {
        http:Response res = check apiClient->post("/assets", asset);
        io:println("  " + asset.assetTag + ": " + res.statusCode.toString());
    }

    // Seed schedules with fixed IDs.

    check addScheduleQuietly("NUST-LIB-LAP-002",
        {scheduleId: "SCH001", 'type: "MAINTENANCE", dueDate: "2024-01-15", description: "Annual Service (Overdue)"});
    check addScheduleQuietly("UNAM-ROOM-LAB-001",
        {scheduleId: "SCH002", 'type: "BOOKING", dueDate: "2024-05-20", description: "Booking Return (Overdue)"});
    check addScheduleQuietly("NUST-ENG-OSC-005",
        {scheduleId: "SCH003", 'type: "MAINTENANCE", dueDate: "2023-09-30", description: "Calibration (Overdue)"});
    check addScheduleQuietly("NUST-LIB-3DP-001",
        {scheduleId: "SCH004", 'type: "MAINTENANCE", dueDate: "2030-12-01", description: "Future Calibration"});

    io:println("Seed Done.");
}

function addScheduleQuietly(string tag, Schedule schedule) returns error? {
    http:Response _ = check apiClient->post("/assets/" + tag + "/schedules", schedule);
}

// Print helpers.

// Short line for users: tag, name, status.
function printShort(Asset a) {
    io:println("  [" + a.assetTag + "] " + a.name + " | " + a.status);
}

// Full details for admins.
function printFull(Asset a) {
    io:println("  Tag:         " + a.assetTag);
    io:println("  Name:        " + a.name);
    io:println("  Description: " + a.description);
    io:println("  Institution: " + a.institution);
    io:println("  Site:        " + a.site);
    io:println("  Status:      " + a.status);
    io:println("  Acquired:    " + a.dateAcquired);
    Schedule[] schedules = a.schedules ?: [];
    if schedules.length() > 0 {
        io:println("  Schedules:");
        foreach Schedule s in schedules {
            io:println("    [" + s.scheduleId + "] " + s.'type + " Due " + s.dueDate + ": " + s.description);
        }
    }
}

function pause() {
    _ = io:readln("\nPress Enter To Return... ");
}
