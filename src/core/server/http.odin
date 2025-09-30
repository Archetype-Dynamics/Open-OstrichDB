package server

import "core:fmt"
import "core:strings"
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
            Contains logic for building and parsing HTTP
						requests and responses.
*********************************************************/

@(require_results)
make_new_http_status ::proc(code: lib.HttpStatusCode, text: string  ) ->^lib.HttpStatus {
    using lib

    httpStatus:= new(HttpStatus)
    httpStatus.statusCode = code
    httpStatus.text = text

    return httpStatus
}

@(require_results)
parse_http_request :: proc(rawData:[]byte) -> (method: lib.HttpMethod, path: string, headers: map[string]string){
    using lib
    using strings

    lines:= split(string(rawData), "\r\n")
    defer delete(lines)

    if len(lines) < 1 {
        return nil, "Http request empty", nil
    }

    requestParts:= fields(lines[0])
    defer delete(requestParts)

   	if len(requestParts) != 3 {
		return nil, "", nil
	}

	methodStringPart := trim_space(requestParts[0])

	for httpMethod , index in HttpMethodString{
	    if methodStringPart == httpMethod{
		   method = index
			break
	   }
	}

	path = trim_space(requestParts[1])

	//Create a map to store the headers
	headers = make(map[string]string)
	headerEnd := 1

	//Iterate through the lines of the request
	for i := 1; i < len(lines); i += 1 {
		if lines[i] == "" { 	//if the line is empty, the headers are done and set the headerEnd to the current index
			headerEnd = i
			break
		}

		//split the line into key and value
		headerParts := strings.split(lines[i], ": ")
		defer delete(headerParts)

		//if theline has 2 parts, add it to the headers map
		if len(headerParts) == 2 {
			headers[headerParts[0]] = headerParts[1]
		}

	}

	return method, path, headers
}

//builds an HTTP response with the passed in status code, headers, and body then returns the response
@(require_results)
build_http_response :: proc(status: ^lib.HttpStatus, headers: map[string]string, body: string) -> []byte {
    using lib
    using fmt
    using strings
    v, loadedVersion:= get_ost_version()
    if !loadedVersion do return []byte{}
	version := tprintf("Server Version: %s\r\n", string(v))
	response := tprintf("HTTP/1.1 %d %s\r\n", int(status.statusCode), status.text)

	//Add default headers
	response = concatenate([]string{response, version})
	response = concatenate([]string{response, tprintf("Content-Length: %d\r\n", len(body))})
	response = concatenate([]string{response, "Connection: close\r\n"})

	//Add custom headers
	for key, value in headers {
		response = concatenate([]string{response, tprintf("%s: %s\r\n", key, value)})
	}

	response = concatenate([]string{response, "\r\n"})

	//if theres a body, add it to the response
	if len(body) > 0 {
		response = concatenate([]string{response, body})
	}

	return transmute([]byte)response
}