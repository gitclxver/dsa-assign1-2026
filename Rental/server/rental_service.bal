import ballerina/grpc;
import ballerina/log;
import ballerina/time;

listener grpc:Listener ep = new (9090);

// Internal booking record kept in the temporary cart until confirmed.
type BookingEntry record {|
    string booking_id;
    string property_id;
    string guest_name;
    string check_in;
    string check_out;
    boolean confirmed;
|};

// In memory data stores keyed by unique id.
map<Property> propertyTable = {};
map<User> userTable = {};
map<BookingEntry> bookingTable = {};

int propertyCounter = 0;
int bookingCounter = 0;

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on ep {

    // Register a new property and return a generated property id.
    remote function add_property(AddPropertyRequest value) returns AddPropertyResponse|error {
        Property property = value.property;
        propertyCounter += 1;
        property.property_id = "PROP" + propertyCounter.toString();
        propertyTable[property.property_id] = property;
        log:printInfo("Property Added: " + property.property_id);
        return {property_id: property.property_id};
    }

    // Create many users via client streaming, confirm once at the end.
    remote function create_users(stream<User, grpc:Error?> clientStream) returns CreateUsersResponse|error {
        int count = 0;
        while true {
            record {|User value;|}? next = check clientStream.next();
            if next is () {
                break;
            }
            User user = next.value;
            if user.user_id != "" && !userTable.hasKey(user.user_id) {
                userTable[user.user_id] = user;
                count += 1;
            }
        }
        return {count: count, message: count.toString() + " User(s) Registered Successfully"};
    }

    // Update a listing by property id.
    remote function update_property(UpdatePropertyRequest value) returns Property|error {
        string id = value.property_id;
        if !propertyTable.hasKey(id) {
            return error("Property " + id + " Not Found");
        }
        Property updated = value.property;
        updated.property_id = id;
        propertyTable[id] = updated;
        return updated;
    }

    // Remove a listing and return remaining available properties in that region.
    remote function remove_property(RemovePropertyRequest value) returns PropertyList|error {
        string id = value.property_id;
        if !propertyTable.hasKey(id) {
            return error("Property " + id + " Not Found");
        }
        Property removed = propertyTable.remove(id);
        string region = removed.location;
        Property[] regionProps = from Property p in propertyTable
            where p.location == region && p.status == AVAILABLE
            select p;
        return {properties: regionProps};
    }

    // Stream available properties, optionally filtered by location or price.
    remote function list_available_properties(ListAvailableRequest value) returns stream<Property, error?>|error {
        string loc = value.location.toLowerAscii().trim();
        Property[] matches = from Property p in propertyTable
            where p.status == AVAILABLE
                && (loc == "" || p.location.toLowerAscii().includes(loc))
                && (value.min_price == 0.0 || p.price_per_night >= value.min_price)
                && (value.max_price == 0.0 || p.price_per_night <= value.max_price)
            select p;
        return matches.toStream();
    }

    // Look up by id or name (case insensitive, partial match on name).
    remote function search_property(SearchPropertyRequest value) returns SearchPropertyResponse|error {
        string query = value.property_id.toLowerAscii().trim();
        if query == "" {
            return {found: false, message: "No Matches.", property: {}};
        }

        // Exact id match first (case insensitive).
        foreach Property p in propertyTable {
            if p.property_id.toLowerAscii() == query {
                return {found: true, message: "Property Found", property: p};
            }
        }

        // Then match by name (partial, case insensitive).
        foreach Property p in propertyTable {
            if p.name.toLowerAscii().includes(query) {
                return {found: true, message: "Property Found", property: p};
            }
        }

        return {found: false, message: "No Matches.", property: {}};
    }

    // Add a booking to the temporary cart after validation.
    remote function book_property(BookPropertyRequest value) returns BookPropertyResponse|error {
        if !propertyTable.hasKey(value.property_id) {
            return {success: false, message: "Property Not Found", booking_id: ""};
        }
        Property property = propertyTable.get(value.property_id);
        if property.status != AVAILABLE {
            return {success: false, message: "Property Is Not Available", booking_id: ""};
        }
        if !isValidDate(value.check_in) || !isValidDate(value.check_out) {
            return {success: false, message: "Dates Must Be YYYY-MM-DD (Example: 2026-07-26)", booking_id: ""};
        }
        if value.check_out <= value.check_in {
            return {success: false, message: "Check Out Date Must Be After Check In Date", booking_id: ""};
        }
        bookingCounter += 1;
        string bookingId = "BK" + bookingCounter.toString();
        bookingTable[bookingId] = {
            booking_id: bookingId,
            property_id: value.property_id,
            guest_name: value.guest_name,
            check_in: value.check_in,
            check_out: value.check_out,
            confirmed: false
        };
        return {success: true, message: "Booking Added To Cart", booking_id: bookingId};
    }

    // Finalize a booking: check overlaps, calculate cost, confirm.
    remote function confirm_booking(ConfirmBookingRequest value) returns ConfirmBookingResponse|error {
        BookingEntry? maybeBooking = findBooking(value.booking_id);
        if maybeBooking is () {
            return {success: false, message: "Booking Not Found", booking_id: value.booking_id, nights: 0, total_cost: 0.0};
        }
        BookingEntry booking = maybeBooking;
        if booking.guest_name.toLowerAscii() != value.guest_name.toLowerAscii().trim() {
            return {success: false, message: "Booking Does Not Belong To This Guest", booking_id: booking.booking_id, nights: 0, total_cost: 0.0};
        }
        if !propertyTable.hasKey(booking.property_id) {
            return {success: false, message: "Property No Longer Exists", booking_id: booking.booking_id, nights: 0, total_cost: 0.0};
        }

        // Ensure no date overlap with already confirmed bookings of the same property.
        BookingEntry[] confirmed = from BookingEntry b in bookingTable
            where b.property_id == booking.property_id && b.confirmed && b.booking_id != booking.booking_id
            select b;
        foreach BookingEntry other in confirmed {
            if booking.check_in < other.check_out && other.check_in < booking.check_out {
                return {success: false, message: "Property Is Already Booked For Those Dates", booking_id: booking.booking_id, nights: 0, total_cost: 0.0};
            }
        }

        int|error nightsResult = nightsBetween(booking.check_in, booking.check_out);
        if nightsResult is error {
            return {success: false, message: "Invalid Booking Dates. Use YYYY-MM-DD", booking_id: booking.booking_id, nights: 0, total_cost: 0.0};
        }
        int nights = nightsResult;
        Property property = propertyTable.get(booking.property_id);
        float totalCost = property.price_per_night * <float>nights;

        // Mark booking confirmed and property unavailable.
        booking.confirmed = true;
        bookingTable[booking.booking_id] = booking;
        property.status = UNAVAILABLE;
        propertyTable[property.property_id] = property;

        return {
            success: true,
            message: "Booking Confirmed",
            booking_id: booking.booking_id,
            nights: nights,
            total_cost: totalCost
        };
    }
}

// Find a booking by id (case insensitive).
function findBooking(string bookingId) returns BookingEntry? {
    string wanted = bookingId.trim().toUpperAscii();
    if bookingTable.hasKey(wanted) {
        return bookingTable.get(wanted);
    }
    foreach BookingEntry b in bookingTable {
        if b.booking_id.toUpperAscii() == wanted {
            return b;
        }
    }
    return ();
}

// True when date is a real YYYY-MM-DD value.
function isValidDate(string date) returns boolean {
    string d = date.trim();
    if d.length() != 10 {
        return false;
    }
    if d.substring(4, 5) != "-" || d.substring(7, 8) != "-" {
        return false;
    }
    time:Utc|error parsed = time:utcFromString(d + "T00:00:00Z");
    return parsed is time:Utc;
}

// Count nights between two date strings (format YYYY-MM-DD).
function nightsBetween(string checkIn, string checkOut) returns int|error {
    time:Utc inUtc = check time:utcFromString(checkIn + "T00:00:00Z");
    time:Utc outUtc = check time:utcFromString(checkOut + "T00:00:00Z");
    decimal seconds = time:utcDiffSeconds(outUtc, inUtc);
    return <int>(seconds / 86400d);
}
