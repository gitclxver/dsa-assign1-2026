import ballerina/log;
import ballerina/time;

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

// Error constants.

public const ASSET_NOT_FOUND = "AssetNotFound";
public const ASSET_ALREADY_EXISTS = "AssetAlreadyExists";
public const ASSET_TAG_MISMATCH = "AssetTagMismatch";
public const COMPONENT_NOT_FOUND = "ComponentNotFound";
public const SCHEDULE_NOT_FOUND = "ScheduleNotFound";
public const WORKORDER_NOT_FOUND = "WorkOrderNotFound";
public const INSTITUTION_NOT_FOUND = "InstitutionNotFound";
public const INSTITUTION_ALREADY_EXISTS = "InstitutionAlreadyExists";



public class LibraryRepository {

    // Maps assetTag to Asset.
    private final map<Asset> assets = {};
    // Maps institution name to true (registry of institutions).
    private final map<boolean> institutions = {};

    public function init() {
    }

    // Create
    public function createAsset(Asset asset) returns Asset|error {
        if self.assets.hasKey(asset.assetTag) {
            return error(ASSET_ALREADY_EXISTS);
        }
        self.assets[asset.assetTag] = asset.clone();
        self.institutions[asset.institution] = true;
        log:printInfo("Asset created: " + asset.assetTag);
        return asset.clone();
    }

    // Read all
    public function getAllAssets() returns Asset[] {
        Asset[] result = [];
        foreach var [_, asset] in self.assets.entries() {
            result.push(asset.clone());
        }
        return result;
    }

    // Read one
    public function getAsset(string assetTag) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        return maybeAsset.clone();
    }

    // Update
    public function updateAsset(string assetTag, Asset asset) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        if assetTag != asset.assetTag {
            return error(ASSET_TAG_MISMATCH);
        }
        // Keep components/schedules/workOrders, update top-level fields only
        Asset existing = maybeAsset.clone();
        existing.name = asset.name;
        existing.description = asset.description;
        existing.institution = asset.institution;
        existing.site = asset.site;
        existing.status = asset.status;
        existing.dateAcquired = asset.dateAcquired;
        self.assets[assetTag] = existing;
        self.institutions[asset.institution] = true;
        log:printInfo("Asset updated: " + assetTag);
        return existing.clone();
    }

    // Delete
    public function deleteAsset(string assetTag) returns error? {
        if !self.assets.hasKey(assetTag) {
            return error(ASSET_NOT_FOUND);
        }
        _ = self.assets.remove(assetTag);
        log:printInfo("Asset deleted: " + assetTag);
        return;
    }

    // Filter by institution
    public function getAssetsByInstitution(string institution) returns Asset[] {
        Asset[] result = [];
        foreach var [_, asset] in self.assets.entries() {
            if asset.institution == institution {
                result.push(asset.clone());
            }
        }
        return result;
    }

    // Filter by site/campus
    public function getAssetsBySite(string site) returns Asset[] {
        Asset[] result = [];
        foreach var [_, asset] in self.assets.entries() {
            if asset.site == site {
                result.push(asset.clone());
            }
        }
        return result;
    }

    // Overdue: any schedule whose dueDate has passed (dueDate before today).
    // utcToString() gives an ISO date, so the first 10 characters are the date
    // we can compare against the schedule dueDate.
    public function getOverdueAssets() returns Asset[] {
        string today = time:utcToString(time:utcNow()).substring(0, 10);
        Asset[] result = [];
        foreach var [_, asset] in self.assets.entries() {
            Schedule[] schedules = asset.schedules ?: [];
            foreach Schedule s in schedules {
                if s.dueDate < today {
                    result.push(asset.clone());
                    break;
                }
            }
        }
        return result;
    }

    // Components.
    public function addComponent(string assetTag, Component component) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        Component[] components = asset.components ?: [];
        components.push(component);
        asset.components = components;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    public function removeComponent(string assetTag, string compId) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        Component[] components = asset.components ?: [];
        Component[] remaining = components.filter(c => c.compId != compId);
        if remaining.length() == components.length() {
            return error(COMPONENT_NOT_FOUND);
        }
        asset.components = remaining;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    // Schedules.
    public function addSchedule(string assetTag, Schedule schedule) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        Schedule[] schedules = asset.schedules ?: [];
        schedules.push(schedule);
        asset.schedules = schedules;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    public function removeSchedule(string assetTag, string scheduleId) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        Schedule[] schedules = asset.schedules ?: [];
        Schedule[] remaining = schedules.filter(s => s.scheduleId != scheduleId);
        if remaining.length() == schedules.length() {
            return error(SCHEDULE_NOT_FOUND);
        }
        asset.schedules = remaining;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    // Work orders.
    public function addWorkOrder(string assetTag, WorkOrder workOrder) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        WorkOrder[] workOrders = asset.workOrders ?: [];
        workOrders.push(workOrder);
        asset.workOrders = workOrders;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    public function updateWorkOrder(string assetTag, string orderId, WorkOrder workOrder) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        WorkOrder[] workOrders = asset.workOrders ?: [];
        boolean found = false;
        WorkOrder[] updated = [];
        foreach WorkOrder wo in workOrders {
            if wo.orderId == orderId {
                updated.push(workOrder);
                found = true;
            } else {
                updated.push(wo);
            }
        }
        if !found {
            return error(WORKORDER_NOT_FOUND);
        }
        asset.workOrders = updated;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    public function removeWorkOrder(string assetTag, string orderId) returns Asset|error {
        Asset? maybeAsset = self.assets[assetTag];
        if maybeAsset is () {
            return error(ASSET_NOT_FOUND);
        }
        Asset asset = maybeAsset.clone();
        WorkOrder[] workOrders = asset.workOrders ?: [];
        WorkOrder[] remaining = workOrders.filter(wo => wo.orderId != orderId);
        if remaining.length() == workOrders.length() {
            return error(WORKORDER_NOT_FOUND);
        }
        asset.workOrders = remaining;
        self.assets[assetTag] = asset;
        return asset.clone();
    }

    // Institutions registry.
    public function addInstitution(string name) returns error? {
        if self.institutions.hasKey(name) {
            return error(INSTITUTION_ALREADY_EXISTS);
        }
        self.institutions[name] = true;
        return;
    }

    public function removeInstitution(string name) returns error? {
        if !self.institutions.hasKey(name) {
            return error(INSTITUTION_NOT_FOUND);
        }
        _ = self.institutions.remove(name);
        return;
    }

    public function getInstitutions() returns string[] {
        return self.institutions.keys();
    }
}

