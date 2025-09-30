package users

import "core:os"
import "core:fmt"
import "core:strings"
import "core:time"
import "core:encoding/json"
import lib"../../../library"
import C"core:c/libc"

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
            Contains logic for limiting user request on the server
*********************************************************/

@(require_results)
create_user_rate_limit_dir:: proc(user: ^lib.User) -> ^lib.Error{
    using lib
    using C

    if !os.exists(fmt.tprintf("%s/rate_limits", user.id )){
        userCString:= fmt.ctprintf("cd %s && mkdir rate_limits", user.id)
        system(userCString)
    }

    return no_error()
}

@(require_results, cold)
create_user_rate_limit_file :: proc(user: ^lib.User) -> ^lib.Error{
    using lib

    userRateLimitFile:= fmt.tprintf("%s/rate_limits/requests.json", user.id)
    file, creationError:= os.open(userRateLimitFile, os.O_CREATE, FILE_MODE_RW_ALL)
    if creationError == .Exist do return no_error()
    if creationError != nil{
        return make_new_err(.STANDARD_CANNOT_CREATE_FILE, get_caller_location())
    }

    initialData := RateLimitInfo{
        count = 0,
        windowStart = time.now(),
        lastRequest = time.now(),
    }

    jsonData, marshalErr := json.marshal(initialData)
    if marshalErr != nil {
        return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())
    }

    _, writeErr := os.write(file, jsonData)
    if writeErr != 0 {
        return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())
    }

    os.close(file)
    return no_error()
}

@(require_results)
setup_user_rate_limiting ::proc(user: ^lib.User) -> ^lib.Error{
    using lib

    dirResult:= create_user_rate_limit_dir(user)
    if dirResult != nil do return dirResult;

    fileResult:= create_user_rate_limit_file(user)
    if fileResult != nil do return fileResult;

    return no_error()
}

@(require_results)
get_user_rate_limit_info :: proc(user: ^lib.User) -> (rateLimitInfo: ^lib.RateLimitInfo, err: ^lib.Error) {
    using lib

    userRateLimitFile:= fmt.tprintf("%s/rate_limits/requests.json", user.id)

    if !os.exists(userRateLimitFile) {
        setupErr := setup_user_rate_limiting(user)
        if setupErr != nil do return new(RateLimitInfo), setupErr
    }

    fileData, readSuccess := read_file(userRateLimitFile, get_caller_location())
    if readSuccess == false {
        return new(RateLimitInfo), make_new_err(.STANDARD_CANNOT_READ_FILE, get_caller_location())
    }

    rateLimitData := new(RateLimitInfo)
    unmarshalErr := json.unmarshal(fileData, rateLimitData)
    if unmarshalErr != nil {
        rateLimitData.count = 0
        rateLimitData.windowStart = time.now()
        rateLimitData.lastRequest = time.now()
    }

    return rateLimitData, no_error()
}

@(require_results)
update_user_rate_limit_info :: proc(user: ^lib.User, rateLimitInfo: ^lib.RateLimitInfo) -> ^lib.Error {
    using lib

    userRateLimitFile:= fmt.tprintf("%s/rate_limits/requests.json", user.id)

    jsonData, marshalErr := json.marshal(rateLimitInfo^)
    if marshalErr != nil {
        return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())
    }

    file, openErr := os.open(userRateLimitFile, os.O_WRONLY | os.O_TRUNC, FILE_MODE_RW_ALL)
    if openErr != 0 {
        return make_new_err(.STANDARD_CANNOT_OPEN_FILE, get_caller_location())
    }
    defer os.close(file)

    _, writeErr := os.write(file, jsonData)
    if writeErr != 0 {
        return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())
    }

    return no_error()
}

@(require_results)
check_rate_limit :: proc(user: ^lib.User, rateLimitPerMinute: int) -> (allowed: bool, err: ^lib.Error) {
    using lib
    using time

    rateLimitInfo, getErr := get_user_rate_limit_info(user)
    if getErr != nil do return false, getErr

    currentTime := now()

    if duration_seconds(diff(currentTime, rateLimitInfo.windowStart)) >= MINUTE_IN_SECONDS {
        rateLimitInfo.count = 0
        rateLimitInfo.windowStart = currentTime
    }

    if rateLimitInfo.count >= rateLimitPerMinute {
        log_user_server_event(user, make_new_server_event(
            fmt.tprintf("Rate limit exceeded: %d requests in current window (limit: %d)",
                       rateLimitInfo.count, rateLimitPerMinute),
            ServerEventType.WARNING, currentTime, true, "", HttpMethod.GET))

        return false, no_error()
    }

    rateLimitInfo.count += 1
    rateLimitInfo.lastRequest = currentTime

    updateErr := update_user_rate_limit_info(user, rateLimitInfo)
    if updateErr != nil do return false, updateErr

    return true, no_error()
}
