package library

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import conv "core:strconv"
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
            This file contains all the logic for interacting with
            collections within the OstrichDB engine.
*********************************************************/


main :: proc() {
	os.make_directory(LOG_DIR_PATH)
	create_log_files()
}


create_log_files :: proc() -> ^Error {
	runtimeFile, runtimeLogOpenError := os.open(RUNTIME_LOG_PATH, os.O_CREATE, 0o666)
	if runtimeLogOpenError != 0 {
		return make_new_err(.STANDARD_CANNOT_CREATE_FILE, get_caller_location())
	}

	defer os.close(runtimeFile)

	errorFile, errorLogOpenError := os.open(ERROR_LOG_PATH, os.O_CREATE, 0o666)
	if errorLogOpenError != 0 {
		return make_new_err(.STANDARD_CANNOT_CREATE_FILE, get_caller_location())
	}

	os.close(errorFile)
	return make_new_err(.STANDARD_NONE, get_caller_location())
}

//###############################|RUNTIME LOGGING|############################################
@(cold)
log_runtime_event :: proc(eventName: string, eventDesc: string) -> ^Error {
    using fmt
    using strings

	date, h, m, s := get_date_and_time()
	defer delete(date)
	defer delete(h)
	defer delete(m)
	defer delete(s)


	runtimeEventName:= tprintf("Event Name: %s\n", eventName)
	runtimeEventDesc:= tprintf("Event Description: %s\n", eventDesc)
	defer delete(runtimeEventName)
	defer delete(runtimeEventDesc)

	runtimeLogBlock:= concatenate([]string{runtimeEventName, runtimeEventDesc})
	defer delete(runtimeLogBlock)

	fullLogMessage := concatenate(
		[]string {
			runtimeLogBlock,
			"Event Logged: ",
			date,
			"@ ",
			h,
			":",
			m,
			":",
			s,
			" GMT\n",
			"---------------------------------------------\n",
		},
	)
	defer delete(fullLogMessage)

	runtimeLogData := transmute([]u8)fullLogMessage
	defer delete(runtimeLogData)

	runtimeFile, openSuccess := os.open(RUNTIME_LOG_PATH, os.O_APPEND | os.O_RDWR, 0o666)
	defer os.close(runtimeFile)
	if openSuccess != 0 {
		return make_new_err(.STANDARD_CANNOT_OPEN_FILE, get_caller_location())
	}


	_, writeSuccess := os.write(runtimeFile, runtimeLogData)
	if writeSuccess != 0 {
		return make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())
	}

	os.close(runtimeFile)
	return no_error()
}


//###############################|ERROR LOGGING|############################################
log_err :: proc(message: string, location: SourceCodeLocation) -> ^Error {
    using fmt
    using strings

    date, h, m, s := get_date_and_time()
    defer delete(date)
    defer delete(h)
    defer delete(m)
    defer delete(s)

    errMessageString := tprintf("Error: %s\n", message)
    errSourceCodeFile := tprintf("Source Code File: %s\n", location.file_path)
    errProcedure := tprintf("Procedure: %s\n", location.procedure)
    errLine := tprintf("Line: #%d \n", location.line)

    errorLogBlock := concatenate([]string{errMessageString, errSourceCodeFile, errProcedure, errLine})
    defer delete(errorLogBlock)

    fullLog := concatenate(
        []string {
            errorLogBlock,
            "Error Occured: ",
            date,
            "@ ",
            h,
            ":",
            m,
            ":",
            s,
            " GMT\n",
            "---------------------------------------------\n",
        },
    )

    errLogData := transmute([]u8)fullLog
    defer delete(errLogData)

    errorFile, openSuccess := os.open(ERROR_LOG_PATH, os.O_APPEND | os.O_RDWR, 0o666)
    if openSuccess != 0 {
        // DON'T call make_new_err here - just print to console and return
        printf("WARNING: Cannot write to error log file: %s\n", ERROR_LOG_PATH)

        // Create simple error without recursion
        error := new(Error)
        error.message = "Could Not Open Error Log File"
        error.location = location
        return error
    }

    _, writeSuccess := os.write(errorFile, errLogData)
    if writeSuccess != 0 {
        // DON'T call make_new_err here either
        printf("WARNING: Cannot write to error log file\n")
        os.close(errorFile)

        error := new(Error)
        error.message = "Could Not Write To Error Log File"
        error.location = location
        return error
    }

    delete(errMessageString)
    delete(errSourceCodeFile)
    delete(errProcedure)
    delete(errLine)
    delete(fullLog)

    defer os.close(errorFile)
    return no_error()
}