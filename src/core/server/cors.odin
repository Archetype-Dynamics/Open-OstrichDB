package server

import "core:fmt"
import "core:strings"
import "../config"
import lib "../../library"
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
            Contains logic for handling Cross-Origin Resource Sharing (CORS)
            for the OstrichDB server.
*********************************************************/

// Apply CORS headers to response
apply_cors_headers :: proc(headers: ^map[string]string, requestHeaders: map[string]string, method: lib.HttpMethod) {
    using lib
    using fmt
    using strings

    //Get the Origin header from the request
    origin, hasOrigin := requestHeaders["Origin"]

    //Handle file:// protocol (null origin) or missing origin
    if !hasOrigin || origin == "null" || origin == "" {
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,X-Requested-With"
        return
    }

    // Load CORS config safely
    corsOptions := make_default_cors_options()
    if corsOptions == nil {
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization,X-Requested-With"
        return
    }
    defer free(corsOptions)

    // Check if the origin is allowed
    isAllowed := false
    for allowedOrigin in corsOptions.allowOrigins {

        if allowedOrigin == "*" || allowedOrigin == origin {
            isAllowed = true
            break
        }

        // Check for wildcard subdomains
        if has_suffix(allowedOrigin, "://*") {
            protocolParts := split(allowedOrigin, "://*")
            if len(protocolParts) > 0 {
                protocol := protocolParts[0]
                expectedPrefix := tprintf("%s://", protocol)
                if has_prefix(origin, expectedPrefix) {
                    isAllowed = true
                    break
                }
            }
        }
    }

    if isAllowed {
        headers["Access-Control-Allow-Origin"] = origin

        if corsOptions.allowCredentials {
            headers["Access-Control-Allow-Credentials"] = "true"
        }

        if method == .OPTIONS {
            // Convert HttpMethod enum to strings
            methodStrings := make([dynamic]string)
            defer delete(methodStrings)

            for httpMethod in corsOptions.allowMethods {
                switch httpMethod {
                case .GET:    append(&methodStrings, "GET")
                case .POST:   append(&methodStrings, "POST")
                case .PUT:    append(&methodStrings, "PUT")
                case .DELETE: append(&methodStrings, "DELETE")
                case .HEAD:   append(&methodStrings, "HEAD")
                case .OPTIONS: append(&methodStrings, "OPTIONS")
                }
            }

            if len(methodStrings) > 0 {
                allowedMethodsString := join(methodStrings[:], ", ")
                headers["Access-Control-Allow-Methods"] = allowedMethodsString
            }

            if len(corsOptions.allowHeaders) > 0 {
                allowedHeadersString := join(corsOptions.allowHeaders, ", ")
                headers["Access-Control-Allow-Headers"] = allowedHeadersString
            }

            maxAgeString := tprintf("%d", corsOptions.maxAge)
            headers["Access-Control-Max-Age"] = maxAgeString
        }

        if len(corsOptions.exposeHeaders) > 0 {
            exposeHeadersString := join(corsOptions.exposeHeaders, ", ")
            headers["Access-Control-Expose-Headers"] = exposeHeadersString
        }
    }
}

// Default CORS options that allow specific origins and common methods
make_default_cors_options :: proc() -> ^lib.CorsOptions {
    using lib
    using fmt
    using config

    defaultCorsOptions := new(lib.CorsOptions)
    if defaultCorsOptions == nil {
        free(defaultCorsOptions)
        return nil
    }

    // Load config safely
    appConfig := load_config_with_dotenv()
    if appConfig == nil {
        free(defaultCorsOptions)
        return nil
    }

    defaultCorsOptions.allowOrigins = appConfig.cors.allowedOrigins
    defaultCorsOptions.allowMethods = appConfig.cors.allowedMethods
    defaultCorsOptions.allowHeaders = appConfig.cors.allowedHeaders
    defaultCorsOptions.exposeHeaders = []string{}
    defaultCorsOptions.allowCredentials = appConfig.cors.allowCredentials
    defaultCorsOptions.maxAge = appConfig.cors.maxAgeSeconds

    return defaultCorsOptions
}

// Handle OPTIONS preflight requests
handle_options_request :: proc(method: lib.HttpMethod, path: string, headers: map[string]string, args: []string = {""}) -> (^lib.HttpStatus, string) {
    using lib
    using fmt

    // Create response headers with CORS headers
    responseHeaders := make(map[string]string)
    defer delete(responseHeaders)

    // Apply CORS options for preflight
    apply_cors_headers(&responseHeaders, headers, method)

    // Return 204 No Content for OPTIONS requests I guess this standard for CORS preflight
    return make_new_http_status(.NO_CONTENT, HttpStatusText[.NO_CONTENT]), ""
}