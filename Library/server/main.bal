import ballerina/http;
import ballerina/log;

import library_management.db;

listener http:Listener httpListener = new (8081);

final db:LibraryRepository repo = new;

service /api on httpListener {

    // Asset CRUD.

    // Create asset
    resource function post assets(db:Asset asset) returns http:Created|http:Conflict {
        db:Asset|error created = repo.createAsset(asset);
        if created is error {
            return <http:Conflict>{body: {message: created.message(), assetTag: asset.assetTag}};
        }
        log:printInfo("Created asset " + asset.assetTag);
        return <http:Created>{body: {message: "Asset created successfully", asset: created}};
    }

    // View all assets
    resource function get assets() returns db:Asset[] {
        return repo.getAllAssets();
    }

    // Overdue dashboard 
    resource function get assets/overdue() returns db:Asset[] {
        return repo.getOverdueAssets();
    }

    // View one asset
    resource function get assets/[string assetTag]() returns db:Asset|http:NotFound {
        db:Asset|error asset = repo.getAsset(assetTag);
        if asset is error {
            return <http:NotFound>{body: {message: asset.message(), assetTag: assetTag}};
        }
        return asset;
    }

    // Update asset
    resource function put assets/[string assetTag](db:Asset asset) returns http:Ok|http:NotFound|http:BadRequest {
        db:Asset|error updated = repo.updateAsset(assetTag, asset);
        if updated is error {
            if updated.message() == db:ASSET_TAG_MISMATCH {
                return <http:BadRequest>{body: {message: "assetTag in URL and body do not match"}};
            }
            return <http:NotFound>{body: {message: updated.message(), assetTag: assetTag}};
        }
        return <http:Ok>{body: {message: "Asset updated successfully", asset: updated}};
    }

    // Delete asset
    resource function delete assets/[string assetTag]() returns http:Ok|http:NotFound {
        error? result = repo.deleteAsset(assetTag);
        if result is error {
            return <http:NotFound>{body: {message: result.message(), assetTag: assetTag}};
        }
        return <http:Ok>{body: {message: "Asset deleted successfully", assetTag: assetTag}};
    }

    // Filtering.

    // Assets by institution
    resource function get assets/institution/[string institution]() returns db:Asset[] {
        return repo.getAssetsByInstitution(institution);
    }

    // Assets by site/campus
    resource function get assets/site/[string site]() returns db:Asset[] {
        return repo.getAssetsBySite(site);
    }

    // Components.

    resource function post assets/[string assetTag]/components(db:Component component) returns http:Ok|http:NotFound {
        db:Asset|error updated = repo.addComponent(assetTag, component);
        if updated is error {
            return <http:NotFound>{body: {message: updated.message(), assetTag: assetTag}};
        }
        return <http:Ok>{body: {message: "Component added successfully", asset: updated}};
    }

    resource function delete assets/[string assetTag]/components/[string compId]() returns http:Ok|http:NotFound {
        db:Asset|error result = repo.removeComponent(assetTag, compId);
        if result is error {
            return <http:NotFound>{body: {message: result.message(), assetTag: assetTag, compId: compId}};
        }
        return <http:Ok>{body: {message: "Component removed successfully", asset: result}};
    }

    // Schedules.

    resource function post assets/[string assetTag]/schedules(db:Schedule schedule) returns http:Ok|http:NotFound {
        db:Asset|error updated = repo.addSchedule(assetTag, schedule);
        if updated is error {
            return <http:NotFound>{body: {message: updated.message(), assetTag: assetTag}};
        }
        return <http:Ok>{body: {message: "Schedule added successfully", asset: updated}};
    }

    resource function delete assets/[string assetTag]/schedules/[string scheduleId]() returns http:Ok|http:NotFound {
        db:Asset|error result = repo.removeSchedule(assetTag, scheduleId);
        if result is error {
            return <http:NotFound>{body: {message: result.message(), assetTag: assetTag, scheduleId: scheduleId}};
        }
        return <http:Ok>{body: {message: "Schedule removed successfully", asset: result}};
    }

    // Work orders.

    resource function post assets/[string assetTag]/workorders(db:WorkOrder workOrder) returns http:Ok|http:NotFound {
        db:Asset|error updated = repo.addWorkOrder(assetTag, workOrder);
        if updated is error {
            return <http:NotFound>{body: {message: updated.message(), assetTag: assetTag}};
        }
        return <http:Ok>{body: {message: "Work order added successfully", asset: updated}};
    }

    resource function put assets/[string assetTag]/workorders/[string orderId](db:WorkOrder workOrder) returns http:Ok|http:NotFound {
        db:Asset|error updated = repo.updateWorkOrder(assetTag, orderId, workOrder);
        if updated is error {
            return <http:NotFound>{body: {message: updated.message(), assetTag: assetTag, orderId: orderId}};
        }
        return <http:Ok>{body: {message: "Work order updated successfully", asset: updated}};
    }

    resource function delete assets/[string assetTag]/workorders/[string orderId]() returns http:Ok|http:NotFound {
        db:Asset|error result = repo.removeWorkOrder(assetTag, orderId);
        if result is error {
            return <http:NotFound>{body: {message: result.message(), assetTag: assetTag, orderId: orderId}};
        }
        return <http:Ok>{body: {message: "Work order removed successfully", asset: result}};
    }

    // Institutions registry.

    resource function get institutions() returns string[] {
        return repo.getInstitutions();
    }

    resource function post institutions(@http:Payload record {|string name;|} body) returns http:Created|http:Conflict {
        error? result = repo.addInstitution(body.name);
        if result is error {
            return <http:Conflict>{body: {message: result.message(), institution: body.name}};
        }
        return <http:Created>{body: {message: "Institution added successfully", institution: body.name}};
    }

    resource function delete institutions/[string name]() returns http:Ok|http:NotFound {
        error? result = repo.removeInstitution(name);
        if result is error {
            return <http:NotFound>{body: {message: result.message(), institution: name}};
        }
        return <http:Ok>{body: {message: "Institution removed successfully", institution: name}};
    }
}
