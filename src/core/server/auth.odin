package server

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:encoding/json"
import "core:encoding/base64"
import lib "../../library"
import "../engine/users"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
All Rights Reserved.

This software is proprietary and confidential. Unauthorized copying,
distribution, modification, or use of this software, in whole or in part,
is strictly prohibited without the express written permission of
Archetype Dynamics, Inc.


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

    user, extractSuccess := extract_user_from_jwt(token)
    if !extractSuccess {
        return "ERROR: Failed to extract user from JWT", false
    }

    return user.id , true
}

//Extract the JWT
@(require_results)
// extract_user_from_jwt :: proc(token: string) -> (userID: string, email: string, success: bool) {
    extract_user_from_jwt :: proc(token: string) -> (user: ^lib.User, success: bool) {
    using strings
    using base64
    using json
    using fmt
    using users

    if len(token) == 0 {
        return  make_new_user("ERROR: Empty token provided"), false
    }

    // JWT format: header.payload.signature
    parts := split(token, ".")
    defer delete(parts)

    if len(parts) != 3 {
        return  make_new_user(tprintf("ERROR: Invalid JWT format: expected 3 parts, got %d\n", len(parts))), false
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
        return  make_new_user(tprintf("ERROR: Failed to decode JWT payload: %v\n", decodeError)), false
    }

    defer delete(payloadBytes)

    if len(payloadBytes) == 0 {
        return  make_new_user("ERROR: Decoded payload is empty"), false
    }

    payloadJSON := string(payloadBytes)

    // Parse JSON payload with better error handling
    payloadData: ClerkJWTPayload
    payloadParseError := unmarshal(transmute([]byte)payloadJSON, &payloadData)
    if payloadParseError != nil {
        return  make_new_user(tprintf("ERROR: Failed to parse JWT payload JSON: %v\nRaw payload: %s\n", payloadParseError, payloadJSON)), false
    }

    // Validate required fields
    if len(payloadData.sub) == 0 {
          return  make_new_user("ERROR: JWT missing 'sub' field or sub field is empty"), false
    }
    extractedUser := users.make_new_user(clone(payloadData.sub),clone(payloadData.email))
    return extractedUser, true
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

    _,success := extract_user_from_jwt(token)
    return success
}

// Extract user information from Authorization header with safety checks
@(require_results)
extract_user_from_auth_header :: proc(headers: map[string]string) -> (user: ^lib.User, success: bool) {
    using strings
    using users

    authHeader, hasAuth := headers["Authorization"]
    if !hasAuth {
        return make_new_user(), false
    }

    if !has_prefix(authHeader, "Bearer ") {
        return make_new_user(), false
    }

    token := trim_prefix(authHeader, "Bearer ")
    token = trim_space(token)

    if !validate_jwt(token) {
        return make_new_user(), false
    }

    return extract_user_from_jwt(token)
}

// Middleware function to check authentication also handles creating users logging dir and files
@(require_results)
require_authentication :: proc(headers: map[string]string) -> (userID: string, authenticated: bool) {
    using fmt
    extractedUser, success := extract_user_from_auth_header(headers)
    if success== true{
        newUser:= users.make_new_user(extractedUser.id)

        dirCreated:= users.make_user_log_dir(newUser)
        filesCreated:= users.create_user_logs(newUser)
        rateLimitSetup:= users.setup_user_rate_limiting(newUser)
}

    return extractedUser.id, success
}

@(require_results)
require_authentication_with_rate_limit :: proc(headers: map[string]string, rateLimitPerMinute: int) -> (userID: string, authenticated: bool, rateLimited: bool) {
    using fmt
    
    extractedUser, success := extract_user_from_auth_header(headers)
    if success != true {
        return extractedUser.id, false, false
    }

    newUser := users.make_new_user(extractedUser.id)
    
    dirCreated := users.make_user_log_dir(newUser)
    filesCreated := users.create_user_logs(newUser)
    rateLimitSetup := users.setup_user_rate_limiting(newUser)

    allowed, rateLimitErr := users.check_rate_limit(newUser, rateLimitPerMinute)
    if rateLimitErr != nil || !allowed {
        return extractedUser.id, true, true
    }

    return extractedUser.id, true, false
}