package server

import "core:fmt"
import "core:net"
import "core:os"
import "core:time"
import "core:c/libc"
import "core:thread"
import "core:strings"
import "core:strconv"
import "../config"
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
            Contains logic for server session information tracking
*********************************************************/
@(private)
serverIsRunning:= false

@(private)
router := make_new_router()

@(private)
newServerSession:= make_new_server_session()

run_ostrich_server :: proc(server: ^lib.Server) -> ^lib.Error {
    using lib
    using fmt

    // Initialize dynamic path system
    pathConfig := config.init_dynamic_paths()
    defer config.cleanup_dynamic_paths()

    // Load application config
    appConfig := config.load_config_with_dotenv()

    serverIsRunning = true

    apiBase := "/api/v1"

    { //START OF TEMP CONTEXT ALLOCATION SCOPE
            context.allocator = context.temp_allocator

            //OPTIONS '/*' dynamic route. CORS preflight related shit. Need these otherwise shit breaks

            //Manual Query Editor
            add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/manual_query", handle_options_request)

            //User account management
            add_route_to_router(router, .OPTIONS,  "/api/v1/user/*", handle_options_request)
            add_route_to_router(router, .OPTIONS,  "/api/v1/user/*/logs/*", handle_options_request)

            //General
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/collections/*/clusters/*/records/*", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/collections/*/clusters/*/records", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/collections/*/clusters/*", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/collections/*/clusters", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/collections/*", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*/collections", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects/*", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/projects", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/api/v1/*", handle_options_request)
           add_route_to_router(router, .OPTIONS, "/*", handle_options_request)


            // '/health' static route for server health
            add_route_to_router(router, .GET, "/health", handle_health_check)

            // '/version' static route
            add_route_to_router(router, .GET, "/version", handle_get_request)

            // manual query editor route
            add_route_to_router(router, .POST, "/api/v1/projects/*/manual_query", handle_post_request)

            //User account management routes
            add_route_to_router(router, .DELETE, fmt.tprintf("%s/user/*", apiBase), handle_delete_request) //deleting thier account
            add_route_to_router(router, .GET, fmt.tprintf("%s/user/*/logs/*", apiBase), handle_get_request) //getting server or non-server error logs

            //User's Project management routes
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects", apiBase), handle_get_request)
            add_route_to_router(router, .POST, fmt.tprintf("%s/projects/*", apiBase), handle_post_request)
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*", apiBase), handle_get_request)
            add_route_to_router(router, .PUT, fmt.tprintf("%s/projects/*", apiBase),  handle_put_request)
            add_route_to_router(router, .DELETE, fmt.tprintf("%s/projects/*", apiBase), handle_delete_request)


            // Collection routes within projects
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*/collections", apiBase), handle_get_request)
            add_route_to_router(router, .POST, fmt.tprintf("%s/projects/*/collections/*", apiBase), handle_post_request)
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*/collections/*", apiBase), handle_get_request)
            add_route_to_router(router, .PUT, fmt.tprintf("%s/projects/*/collections/*", apiBase), handle_put_request)
            add_route_to_router(router, .DELETE, fmt.tprintf("%s/projects/*/collections/*", apiBase), handle_delete_request)


            // Cluster routes within collections
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*/collections/*/clusters", apiBase), handle_get_request)
            add_route_to_router(router, .POST, fmt.tprintf("%s/projects/*/collections/*/clusters/*", apiBase), handle_post_request)
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*/collections/*/clusters/*", apiBase), handle_get_request)
            add_route_to_router(router, .PUT, fmt.tprintf("%s/projects/*/collections/*/clusters/*", apiBase), handle_put_request)
            add_route_to_router(router, .DELETE, fmt.tprintf("%s/projects/*/collections/*/clusters/*", apiBase), handle_delete_request)


            // Record routes within clusters
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*/collections/*/clusters/*/records", apiBase), handle_get_request)
            add_route_to_router(router, .POST, fmt.tprintf("%s/projects/*/collections/*/clusters/*/records/*", apiBase), handle_post_request)
            add_route_to_router(router, .GET, fmt.tprintf("%s/projects/*/collections/*/clusters/*/records/*", apiBase), handle_get_request)
            add_route_to_router(router, .PUT, fmt.tprintf("%s/projects/*/collections/*/clusters/*/records/*", apiBase), handle_put_request)
            add_route_to_router(router, .DELETE, fmt.tprintf("%s/projects/*/collections/*/clusters/*/records/*", apiBase), handle_delete_request)

    } //END OF TEMP CONTEXT ALLOCATION SCOPE


    server.port = appConfig.server.port

    //Parse bind address from config
    bindIP := parse_ip_address(appConfig.server.bindAddress)
    endpoint := net.Endpoint{bindIP, server.port}

    // Use backlog size from config
    listenSocket, listen_err := net.listen_tcp(endpoint, appConfig.server.backlogSize)
    if listen_err != nil {
        printf("Error listening on socket: %v\n", listen_err)
        return make_new_err(.SERVER_CANNOT_LISTEN_ON_SOCKET, get_caller_location())
    }

    defer net.close(net.TCP_Socket(listenSocket))

    printf(
        "OstrichDB server listening on %s:%d (bind: %s)\n",
        appConfig.server.host,
        server.port,
        appConfig.server.bindAddress,
    )
    printf("API Base URL: http://%s:%d%s\n", appConfig.server.host, server.port, apiBase)

    // Main server loop
    for serverIsRunning {
        if appConfig.logging.level == "DEBUG" {
            fmt.println("Waiting for new connection...")
        }

        clientSocket, remoteEndpoint, acceptError := net.accept_tcp(listenSocket)
        if acceptError != nil {
            fmt.println("Error accepting connection: ", acceptError)
            return make_new_err(.SERVER_CANNOT_ACCEPT_CONNECTION, get_caller_location())
        }

        handle_connection(clientSocket, appConfig, router)
    }

    fmt.println("Server stopped successfully")
    return no_error()
}

@(cold)
handle_connection :: proc(socket: net.TCP_Socket, appConfig: ^lib.AppConfig, router: ^lib.Router) -> ^lib.Error{
    using lib
    using fmt

    defer net.close(socket)

    maxBufferSize := appConfig.security.maxRequestBodySizeMb * 1024 * 1024
    buf := make([]byte, min(maxBufferSize, 4096))
    defer delete(buf)

    for {
        println("Waiting to receive data...")

        bytesRead, readTCPSocketError := net.recv(socket, buf[:])
        //FIX ME: Commented due to problems on prod
        // if readTCPSocketError != nil {
            // printf("ERROR: Error reading from socket: %v\n", readTCPSocketError)
            // return make_new_err(.SERVER_CANNOT_READ_FROM_SOCKET,get_caller_location())
        // }

        if bytesRead == 0 {
            println("Connection closed by client")
            return no_error()
        }

        // Parse incoming request
        method, path, headers := parse_http_request(buf[:bytesRead])


        // Extract request body for POST/PUT requests
        request_body := extract_request_body(buf[:bytesRead])
        args := []string{request_body} if len(request_body) > 0 else []string{""}

        // Handle the request using router
        httpStatus, responseBody := handle_http_request(router, method, path, headers, args)

        if appConfig.logging.consoleOutput || appConfig.logging.level == "DEBUG" {
        }

        // Build and send response
        version, versionLoaded := get_ost_version(); if !versionLoaded do continue
        responseHeaders := make(map[string]string)
        responseHeaders["Content-Type"] = "application/json"
        responseHeaders["Server"] = tprintf("OstrichDB:%s", string(version))
        responseHeaders["X-API-Version"] = "v1"

        // Apply CORS headers to response
        apply_cors_headers(&responseHeaders, headers, method)

        response := build_http_response(httpStatus, responseHeaders, responseBody)

        // Write response to socket
        _, writeError := net.send(socket, response)
        defer delete(response) //TODO: If a memory leak ye seek come here and take a peek - Marshall
        if writeError != nil {
            printf("ERROR: Failed to write response to socket: %v\n", writeError)
            return make_new_err(.SERVER_CANNOT_WRITE_RESPONSE_TO_SOCKET, get_caller_location())
        }
    }
}

// Extract request body from HTTP request
@(require_results)
extract_request_body :: proc(data: []byte) -> string {
    using strings

    lines := split(string(data), "\r\n")
    defer delete(lines)

    // Find empty line that separates headers from body
    body_start := -1
    for line, i in lines {
        if len(line) == 0 {
            body_start = i + 1
            break
        }
    }

    if body_start == -1 || body_start >= len(lines) {
        return ""
    }

    // Join remaining lines as body
    body_lines := lines[body_start:]
    body := join(body_lines, "\r\n")
    return clone(trim_space(body))
}

// // Helper proc to parse IP address strings
@(require_results)
parse_ip_address :: proc(ipString: string) -> net.IP4_Address {
    if ipString == "0.0.0.0" {
        return net.IP4_Address{0, 0, 0, 0}
    }
    if ipString == "127.0.0.1" || ipString == "localhost" {
        return net.IP4_Address{127, 0, 0, 1}
    }

    // For more complex IP parsing, you'd implement IP string parsing here
    // For now, default to all interfaces
    return net.IP4_Address{0, 0, 0, 0}
}


// Use thread.run(HANDLE_SERVER_KILL_SWITCH)
@(cold, deprecated= "This kill switch has been deprecated, Not used for Production OstrichDB Server, only OstrichLite or OstrichDB-CLI")
HANDLE_SERVER_KILL_SWITCH :: proc() {
    using lib
    using fmt
    using strings


	for serverIsRunning {
		input := get_input(false)
		if input == "kill" || input == "exit" {
			// println("Stopping OstrichDB server...")
			serverIsRunning = false
			//ping the server to essentially refresh it to ensure it stops thus breaking the server main loop
			for port in ServerPorts{
				portCString := clone_to_cstring(tprintf("nc -zv localhost %d", port))
				libc.system(portCString)
			}
			return
		} else do continue
	}
}
