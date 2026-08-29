import ballerina/http;
import ballerina/log;
import library_management.db;


listener http:Listener httpListener = new (8081);

final db:LibraryRepository repo = new;

server /api on httpListener {
    
    //Create asset
    resource function post assets(db:Assets assets) returns http:Created|http:Conflict {
        db:Asset|erro created = repo.createAsset(assets);
        if created is error {
            return <http:Conflict>{body: {message: created.message(), assetTag: asset.assetTag}};
        }
        log:printInfo("Created assets " + asset.assetTag);
        return <http:Created>{body: {message: "Asset created successfully",asset:}}

    }

    // View all assets
    resource function get assets() returns db:Asset[] {
        return repo.getAllAssets();
    }

    // OVerdue dashboard
    resource function get assets/overdue() returns db:Assets[] {
        return
    }

    resource function get assets/[string assetTag]() returns db:Asset|http:NotFound {
        db:Asset|error asset = repo.getAsset(assetTag);
        if asset is error {
            return <http:NotFound>{body: {message: asset.message(), assetTag: assetTag}};
        }
        return asset;
    }


    // Update asset
    resource function put asstes/[string assetTag](db:Asseet asset) returns http:Ok|http:NotFound|http:BadRequest {
        db:Asseet|error update = repo.updateAsset(assetTag, asset);
        if update is error {
            if updated.message() == db:ASSET_TAG_MISMATCH {
                return <http:BadRequest>{body: {message: "assetTag in URL and body do not match"}};
            }
            return <http:NotFound{body: {message: update.message(), assetTag: assetTag}};
        }
        return <http:Ok>{bodyL {message: "Asset updated successfully", asset: updated}};
    }


} 



