package server

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:encoding/json"
import "core:encoding/base64"
import lib "../../library"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


File Description:
            JWT authentication handling for Clerk integration
*********************************************************/

ClerkJWTPayload :: struct {
    // Standard JWT claims (always present)
    sub: string,           // User ID (subject)
    iss: string,           // Issuer (Clerk domain)
    azp: string,           // Authorized party
    exp: i64,             // Expiration timestamp
    iat: i64,             // Issued at timestamp
    nbf: i64,             // Not before timestamp
    jti: string,          // JWT unique identifier

    // Custom claims (if configured in JWT template)
    email: string,         // User email (from template)
    first_name: string,    // First name (from template)
    last_name: string,     // Last name (from template)
}

// Extract user ID from authorization header with better error handling
@(require_results)
extract_user_id_from_auth :: proc(headers: map[string]string) -> (userID: string, success: bool) {
    using fmt

    authHeader, hasAuth := headers["Authorization"]
    if !hasAuth {
        return "ERROR: No Authorization header found", false
    }

    if !strings.has_prefix(authHeader, "Bearer ") {
        return "ERROR: Authorization header doesn't start with 'Bearer '", false
    }

    token := strings.trim_prefix(authHeader, "Bearer ")
    token = strings.trim_space(token)

    if len(token) == 0 {
        return "ERROR: Empty token after Bearer prefix", false
    }

    extractedID, _, extractSuccess := extract_user_from_jwt(token)
    if !extractSuccess {
        return "ERROR: Failed to extract user from JWT", false
    }

    return extractedID, true
}

//Extract the JWT
@(require_results)
extract_user_from_jwt :: proc(token: string) -> (userID: string, email: string, success: bool) {
    using strings
    using base64
    using json
    using fmt

    if len(token) == 0 {
        return "ERROR: Empty token provided", "", false
    }

    // JWT format: header.payload.signature
    parts := split(token, ".")
    defer delete(parts)

    if len(parts) != 3 {

        return tprintf("ERROR: Invalid JWT format: expected 3 parts, got %d\n", len(parts)), "", false
    }

    // Get the payload
    payload_b64 := parts[1]

    // Add padding if needed for base64 decoding
    padding_needed := (4 - len(payload_b64) % 4) % 4
    for i in 0..<padding_needed {
        payload_b64 = concatenate({payload_b64, "="})
    }

    // Decode the payload with error handling
    payloadBytes, decodeError := decode(payload_b64)
    if decodeError != nil {
        return tprintf("ERROR: Failed to decode JWT payload: %v\n", decodeError), "", false
    }
    defer delete(payloadBytes)

    if len(payloadBytes) == 0 {
        return "ERROR: Decoded payload is empty", "", false
    }

    payloadJSON := string(payloadBytes)

    // Parse JSON payload with better error handling
    payloadData: ClerkJWTPayload
    payloadParseError := unmarshal(transmute([]byte)payloadJSON, &payloadData)
    if payloadParseError != nil {
        return tprintf("ERROR: Failed to parse JWT payload JSON: %v\nRaw payload: %s\n", payloadParseError, payloadJSON), "", false
    }

    // Validate required fields
    if len(payloadData.sub) == 0 {
        return "ERROR: JWT missing 'sub' field or sub field is empty", "", false
    }

    return clone(payloadData.sub), clone(payloadData.email), true
}

// Basic JWT token validation
@(require_results)
validate_jwt :: proc(token: string) -> bool {
    using strings

    if len(token) == 0 {
        return false
    }

    // Check format
    parts := split(token, ".")
    defer delete(parts)

    if len(parts) != 3 {
        return false
    }

    _, _, success := extract_user_from_jwt(token)
    return success
}

// Extract user information from Authorization header with safety checks
@(require_results)
extract_user_from_auth_header :: proc(headers: map[string]string) -> (userID: string, email: string, success: bool) {
    using strings

    authHeader, hasAuth := headers["Authorization"]
    if !hasAuth {
        return "", "", false
    }

    if !has_prefix(authHeader, "Bearer ") {
        return "", "", false
    }

    token := trim_prefix(authHeader, "Bearer ")
    token = trim_space(token)

    if !validate_jwt(token) {
        return "", "", false
    }

    return extract_user_from_jwt(token)
}

// Middleware function to check authentication
@(require_results)
require_authentication :: proc(headers: map[string]string) -> (userID: string, authenticated: bool) {
    using fmt

    extractedUserID, _, success := extract_user_from_auth_header(headers)
    return extractedUserID, success
}