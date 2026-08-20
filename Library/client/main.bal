import ballerina/http;
import ballerina/io;
import ballerina/uuid;

// Talks to the REST API (server must be running on port 8081).
final http:Client apiClient = check new ("http://localhost:8081/api");

// Simple admin password for demo purposes.
const string ADMIN_PASSWORD = "admin123";
