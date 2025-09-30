package server

import "core:fmt"
import "core:strings"
import lib"../../library"
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
            Contains logic for handling HTTP requests and responses.
            Unstable and not fully implemented.
*********************************************************/

@(cold, private)
make_new_router::proc() ->^lib.Router{
    using lib

    router:= new(Router)
    router.routes = make([dynamic]Route, 0)
    return router
}

//Adds a route to the newly created router
add_route_to_router :: proc(router: ^lib.Router,method: lib.HttpMethod, path: string, handler: lib.RouteHandler){
    using lib

	route := Route {
		method = method,
		path = path,
		handler = handler,
	}

	append(&router.routes, route)
}

//This finds the route that matches the path and calls appropriate handler
@(require_results)
handle_http_request :: proc(router: ^lib.Router,method: lib.HttpMethod, path:string, headers: map[string]string, args:[]string={""}) -> (status: ^lib.HttpStatus, response: string,) {
	using lib

	validMethods:[]HttpMethod={.OPTIONS, .GET, .POST, .PUT, .DELETE, .HEAD}

	// First check if the request method is valid
	methodIsValid := false
	for validMethod in validMethods {
		if method == validMethod {
			methodIsValid = true
			break
		}
	}

	if !methodIsValid {
		return make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST]), "Bad Request: Invalid HTTP method"
	}

	// Check each route for a match
	for route in router.routes {
		// Use dynamic path matching
		pathMatch := is_path_match(route.path, path)

		// If the path matches and the method matches, call the handler
		if pathMatch && route.method == method {
			return route.handler(method, path, headers, args)
		}
	}

	// If no route matched, return 404
	return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]), "404 Not Found\n"
}


@(require_results)
is_path_match :: proc(routePath: string, requestPath: string) -> bool {
    using lib
    using strings

	// Split the route and request paths into segments
	routeSegments := split(trim_prefix(routePath, "/"), "/")
	requestSegments := split(trim_prefix(requestPath, "/"), "/")

	defer delete(routeSegments)
	defer delete(requestSegments)

	// Handle query parameters in both route and request paths
	lastRouteSegment := routeSegments[len(routeSegments) - 1]
	lastRequestSegment := requestSegments[len(requestSegments) - 1]


	// Extract base paths (without query parameters)
	if contains(lastRouteSegment, "?") {
		routeSegments[len(routeSegments) - 1] = split(lastRouteSegment, "?")[0]
	}
	if contains(lastRequestSegment, "?") {
		requestSegments[len(requestSegments) - 1] = split(lastRequestSegment, "?")[0]
	}

	// If the length of the route and request segments are not equal, return false
	if len(routeSegments) != len(requestSegments) do return false

	// Iterate through the segments and compare them
	for segment, i in routeSegments {
		if segment == "*" do continue // Skip wildcard segments
		if segment != requestSegments[i] do return false
	}

	// If we have query parameters in the route, verify they exist in the request
	if contains(lastRouteSegment, "?") {

		routeQuery := split(lastRouteSegment, "?")[0]
		requestQuery := split(lastRequestSegment, "?")[0]
		defer delete(routeQuery)
		defer delete(requestQuery)

		// Split query parameters
		route_params := split(routeQuery, "&")
		request_params := split(requestQuery, "&")
		defer delete(route_params)
		defer delete(request_params)

		// Check each required parameter exists
		for param in route_params {
			if param == "*" do continue // Skip wildcard parameters
			paramFound := false
			for req_param in request_params {
				if has_prefix(req_param, split(param, "=")[0]) {
					paramFound = true
					break
				}
			}
			if !paramFound do return false
		}
	}

	return true
}