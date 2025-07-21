package server

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import lib "../../library"
/********************************************************
Author: Marshall A Burns
Copyright (c) 2025‑Present Marshall A Burns and Archetype Dynamics, Inc.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
********************************************************/

// ─────────────────────────────────────────────────────────
//   Logging Helpers (robust, build‑safe version)
// ─────────────────────────────────────────────────────────

// Prevents infinite error spam if log creation fails once.
log_init_failed : bool = false;

// Creates or opens the server log file.  If directory "logs" does
// not exist relative to the executable, it is created on the fly.
@(cold, require_results)
create_server_log_file :: proc(logPath: string) -> ^lib.Error {
    using lib
    using fmt

    // 0. Bail fast if we already failed once.
    if log_init_failed {
        return no_error();
    }

    // 1. Ensure simple "./logs" directory exists.  We avoid advanced
    //    os.path helpers to keep the build portable across Odin versions.
    logDir := "logs";
    if !os.exists(logDir) {
        mkdirErr := os.make_directory(logDir, 0o755);
        if mkdirErr != 0 {
            fmt.println("❌ cannot create log directory:", logDir,
                        " errno:", mkdirErr);
            log_init_failed = true;
            return no_error();
        }
    }

    // 2. Open (or create) the file.
    file, openErr := os.open(logPath, os.O_CREATE | os.O_RDWR, 0o666);
    if openErr != 0 {
        fmt.println("❌ cannot open log file:", logPath,
                    " errno:", openErr);
        log_init_failed = true;
        return no_error();
    }

    os.close(file);
    return no_error();
}

// ─────────────────────────────────────────────────────────
//   Existing code below (unchanged except for logging fix)
// ─────────────────────────────────────────────────────────

// n  - name
// d  - description
// ty - type
// ti - time
// isReq - isRequestEvent
// p  - path
// m  - method
@(require_results)
make_new_server_event :: proc(
    n, d: string,
    ty: lib.ServerEventType,
    ti: time.Time,
    isReq: bool,
    p: string,
    m: lib.HttpMethod,
) -> ^lib.ServerEvent {
    using lib
    event := new(ServerEvent)
    event.name          = n
    event.description   = d
    event.type          = ty
    event.timestamp     = ti
    event.isRequestEvent = isReq
    event.route.path    = p
    event.route.method  = m
    return event
}

// Disabled legacy console printer (kept for future reference)
@(disabled=true)
print_server_event_information :: proc(event: ^lib.ServerEvent) {
    using lib
    using fmt

    println("Server Event Name: ", event.name)
    println("Server Event Description: ", event.description)
    println("Server Event Type: ", event.type)
    println("Server Event Timestamp: ", event.timestamp)
    println("Server Event is a request: ", event.isRequestEvent)

    if event.isRequestEvent == true {
        println("Path used in request event: ", event.route.path)
        println("Method used in request event: ", event.route.method)
    }

    println("\n")
}

// Writes an individual ServerEvent to the log file.
@(require_results)
log_server_event :: proc(event: ^lib.ServerEvent, logFile: string) -> ^lib.Error {
    using lib
    using fmt

    // Quick path check – ensure file exists (no flood if failure)
    if log_init_failed {
        return no_error();
    }

    // Concatenate event details.
    eventTriggered := tprintfln("Server Event Triggered: '%s'", event.name)
    eventTime      := tprintfln("Server Event Time: '%v'", event.timestamp)
    eventDesc      := tprintfln("Server Event Description: '%s'", event.description)
    eventType      := tprintfln("Server Event Type: '%v'", event.type)
    eventIsReq     := tprintfln("Server Event is a Request Event: '%v'", event.isRequestEvent)

    logMsg := strings.concatenate([]string{eventTriggered, eventTime, eventDesc, eventType, eventIsReq})

    concatLogMsg, methodStr: string
    if event.isRequestEvent {
        switch event.route.method {
        case .HEAD:   methodStr = "HEAD"
        case .GET:    methodStr = "GET"
        case .DELETE: methodStr = "DELETE"
        case .POST:   methodStr = "POST"
        case .PUT:    methodStr = "PUT"
        case .OPTIONS: methodStr = "OPTIONS"
        }

        routePath   := tprintf("Server Event Route Path: '%s'\n", event.route.path)
        routeMethod := tprintf("Server Event Route Method: '%s'\n", methodStr)
        concatLogMsg = strings.concatenate([]string{logMsg, routePath, routeMethod, "\n\n"})
    } else {
        concatLogMsg = strings.concatenate([]string{logMsg, "\n\n"})
    }

    logMessage := transmute([]u8) concatLogMsg

    file, openErr := os.open(logFile, os.O_APPEND | os.O_RDWR, 0o666)
    defer os.close(file)
    if openErr != 0 {
        log_init_failed = true;
        return no_error();
    }

    _, writeErr := os.write(file, logMessage)
    if writeErr != 0 {
        log_init_failed = true;
    }
    return no_error()
}
