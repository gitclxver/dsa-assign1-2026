import ballerina/io;

// Data Recods
public type Component record {
    string compId;
    string name;
    string description;
};

public type Schedule record {
    string scheduleId;
    string 'type;  //What is this all about
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

ublic type Asset record {
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

// Error constants.

public const ASSET_NOT_FOUND = "AssetNotFound";
public const ASSET_ALREADY_EXISTS = "AssetAlreadyExists";
public const ASSET_TAG_MISMATCH = "AssetTagMismatch";
public const COMPONENT_NOT_FOUND = "ComponentNotFound";
public const SCHEDULE_NOT_FOUND = "ScheduleNotFound";
public const WORKORDER_NOT_FOUND = "WorkOrderNotFound";
public const INSTITUTION_NOT_FOUND = "InstitutionNotFound";
public const INSTITUTION_ALREADY_EXISTS = "InstitutionAlreadyExists";


public function createLibrary(string name) returns error? {
    io:println("This is where server functions for the library will be implemented");
}
