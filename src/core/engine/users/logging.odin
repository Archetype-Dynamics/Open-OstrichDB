package users

import "core:os"
import "core:fmt"
import "core:strings"
import "core:time"
import C"core:c/libc"
import lib"../../../library"
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
            This file contains all the logic for user specific logging
*********************************************************/
@(require_results)
make_new_server_event :: proc(d: string, ty: lib.ServerEventType,ti: time.Time,isReq: bool,p: string,m: lib.HttpMethod,) -> ^lib.ServerEvent {
    event := new(lib.ServerEvent)
    event.description = d
    event.type = ty
    event.timestamp = ti
    event.isRequestEvent = isReq
    event.route.path = p
    event.route.method = m
    return event
}

LOG_TYPE :: enum {
    ERROR = 0,
    SERVER
}

@(require_results)
make_user_log_dir:: proc(user: ^lib.User) -> ^lib.Error{
    using lib
    using C

    if !os.exists(fmt.tprintf("%s/logs", user.id)){
        userCString:= fmt.ctprintf("cd %s && mkdir logs", user.id)
        system(userCString)
    }

    return no_error()
}

@(require_results, cold)
create_user_error_log_file :: proc(user: ^lib.User) -> ^lib.Error{
    using lib

    userErrorLogFile:= fmt.tprintf("%s/logs/errors.log", user.id)
    file, creationError:= os.open(userErrorLogFile, os.O_CREATE, FILE_MODE_RW_ALL)
    if creationError == .Exist do return no_error()
    if creationError != nil{
        return make_new_err(.STANDARD_CANNOT_CREATE_FILE, get_caller_location())
    }

    return no_error()
}

@(require_results, cold)
create_user_server_log_file :: proc(user: ^lib.User) -> ^lib.Error{
    using lib

    userServerLogFile:= fmt.tprintf("%s/logs/server.log", user.id)
    file, creationError:= os.open(userServerLogFile, os.O_CREATE, FILE_MODE_RW_ALL)
    if creationError == .Exist do return no_error()
    if creationError != nil{
        return make_new_err(.STANDARD_CANNOT_CREATE_FILE, get_caller_location())
    }

    return no_error()
}

@(require_results)
create_user_logs ::proc(user: ^lib.User) -> ^lib.Error{
    using lib

    errLogResult:= create_user_error_log_file(user)
    if errLogResult != nil do return errLogResult;


    servLogResult:= create_user_server_log_file(user)
    if servLogResult != nil do return servLogResult;

    return no_error()
}

log_error_event:: proc(user: ^lib.User, event: ^lib.ErrorEvent) -> ^lib.Error{
    using lib
    using fmt

    userErrorLogFile:= fmt.tprintf("%s/logs/errors.log", user.id)

    eventSeverity := tprintfln("Error Severity: '%v' ", event.severity)
    eventDesc := tprintfln("Error Description: '%s' ", event.description)
    eventTime := tprintfln("Error Time: '%v' ", event.timestamp)
    eventType := tprintfln("Error Type: '%v' \n\n", event.type)


    errorLogBlock := strings.concatenate([]string{eventSeverity,eventDesc,eventTime, eventType})


    file, openErr := os.open(userErrorLogFile, os.O_APPEND | os.O_RDWR, FILE_MODE_RW_ALL)
    defer os.close(file)
    if openErr != 0 do return make_new_err(.STANDARD_CANNOT_OPEN_FILE, get_caller_location());

    blockAsBytes := transmute([]u8)errorLogBlock
    _, writeErr := os.write(file, blockAsBytes)
    if writeErr != 0  do return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())

    return no_error()
}

log_user_server_event :: proc(user: ^lib.User, event: ^lib.ServerEvent) -> ^lib.Error {
    using lib
    using fmt

    fullLogBlock, methodAsStr: string

    userServerLogFile:= fmt.tprintf("%s/logs/server.log", user.id)
    eventDesc := tprintfln("Server Event Description: '%s'", event.description)
    eventTime := tprintfln("Server Event Time: '%v'", event.timestamp)
    eventType := tprintfln("Server Event Type: '%v'", event.type)
    eventIsReq := tprintfln("Server Event is a Request Event: '%v'", event.isRequestEvent)

    firstLogBlock := strings.concatenate([]string{eventDesc,eventTime, eventType, eventIsReq})

    if event.isRequestEvent {
        switch event.route.method {
        case .HEAD:
            methodAsStr = "HEAD"
        case .GET:
            methodAsStr = "GET"
        case .DELETE:
            methodAsStr = "DELETE"
        case .POST:
            methodAsStr = "POST"
        case .PUT:
            methodAsStr = "PUT"
        case .OPTIONS:
            methodAsStr = "OPTIONS"
        }

        //Construct the next portion of the server event log
        routePath  := tprintf("Server Event Route Path: '%s'\n", event.route.path)
        routeMethod := tprintf("Server Event Route Method: '%s'\n", methodAsStr)
        secondLogBlock:=strings.concatenate([]string{routePath, routeMethod, "\n\n" })

        fullLogBlock= strings.concatenate([]string{firstLogBlock, secondLogBlock})
    } else {
        fullLogBlock = strings.concatenate([]string{firstLogBlock, "\n\n"})
    }


    file, openErr := os.open(userServerLogFile, os.O_APPEND | os.O_RDWR, FILE_MODE_RW_ALL)
    defer os.close(file)
    if openErr != 0 do return make_new_err(.STANDARD_CANNOT_OPEN_FILE, get_caller_location());

    blockAsBytes := transmute([]u8)fullLogBlock
    _, writeErr := os.write(file, blockAsBytes)
    if writeErr != 0  do return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())

    return no_error()
}

@(require_results)
get_user_log::proc(user: ^lib.User, logType: LOG_TYPE) -> (data: []u8, err:^lib.Error) {
    using lib

    userLogPath:string

    switch(logType){
        case .ERROR: userLogPath = fmt.tprintf("%s/logs/errors.log", user.id); break
        case .SERVER: userLogPath = fmt.tprintf("%s/logs/server.log", user.id); break
    }

    logData, readSuccess := read_file(userLogPath, get_caller_location())
    if readSuccess == false do return []u8{}, make_new_err(.STANDARD_CANNOT_READ_FILE, get_caller_location())

    return logData, no_error()

}