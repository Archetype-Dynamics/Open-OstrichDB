package library

import "core:os"
import "core:fmt"
import "core:time"
import "core:c/libc"
import "core:strings"
import "core:strconv"
import "core:text/regex"
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
            This file contains all the logic for interacting with
            collections within the OstrichDB engine.
*********************************************************/

// Helper proc that reads an entire file and returns the content as bytes, if the fail thats fine, errors are handled in the caller proc
read_file :: proc(filePath: string, callingProcedure: SourceCodeLocation) -> ([]byte, bool) {
    data, err:=os.read_entire_file(filePath)
    //Do not delete(filePath) here because this helper proc is typically passed arg that is given by an allocator. e.g: concat_standard_collection_name
	return data, err
}

// Helper proc that writes data to a file and returns a success boolean, if the fail thats fine, errors are handled in the caller proc
@(require_results)
write_to_file :: proc(filepath: string, data: []byte, callingProcedure: SourceCodeLocation) -> bool {
    return os.write_entire_file(filepath, data)
}

//Builds and returns a dynamic path based on the passed in project context and collection
//Format: {userID}/projects/{projectName}/collections/{collectionName}.ostrichdb
@(require_results)
get_specific_collection_full_path :: proc(projectContext: ^ProjectContext, collection: ^Collection) -> string {
    return strings.clone(fmt.tprintf("%scollections/%s.ostrichdb", projectContext.basePath, collection.name))
}

//Same as above but for collection backups dir
//Format: {userID}/projects/{projectName}/backups/
@(require_results)
get_project_backup_path :: proc(projectContext: ^ProjectContext) -> string {
    return strings.clone(fmt.tprintf("%sbackups/", projectContext.basePath))
}

//Returns the collections directory path for a project
//Format: {userID}/projects/{projectName}/collections/
@(require_results)
get_collections_path:: proc(projectContext: ^ProjectContext) -> string {
    return strings.clone(fmt.tprintf("%scollections/", projectContext.basePath))
}

//Same as above but for temp dir
//Format: {userID}/projects/{projectName}/temp/
@(require_results)
get_project_temp_path :: proc(projectContext: ^ProjectContext) -> string {
    return strings.clone(fmt.tprintf("%stemp/", projectContext.basePath))
}

//Returns the user's base directory path
//Format: {rootPath}/{userID}/
@(require_results)
get_user_base_path :: proc(userID: string) -> string {
    using fmt
    return strings.clone(fmt.tprintf("./%s/", userID))
}

// Helper to validate user directory structure
@(require_results)
validate_user_directory_structure :: proc(userID: string) -> bool {
    userBasePath := get_user_base_path(userID)
    defer delete(userBasePath)

    requiredDirs := []string{
        fmt.tprintf("%sprojects/", userBasePath),
        fmt.tprintf("%slogs/", userBasePath),
        fmt.tprintf("%stmp/", userBasePath),
    }

    for dir in requiredDirs {
        if _, stat_err := os.stat(dir); stat_err != 0 {
            delete(dir)
            return false
        }
        delete(dir)
    }

    return true
}

//helper to get users input from the command line
@(deprecated= "This procedure is deprectated  do not use")
get_input :: proc(isPassword: bool) -> string {
	buf := new([1024]byte)
	defer free(buf)
	n, err := os.read(os.stdin, buf[:])
	if err != 0 {
		fmt.printfln("%sINTERNAL ERROR%s: OstrichDB failed to read input from command line.", RED, RESET)
		return ""
	}
	result := strings.trim_right(string(buf[:n]), "\r\n")
	return strings.clone(result)
}

get_current_time :: proc() -> time.Time{
    return time.now()
}

//gets the current date in GMT
@(require_results)
get_date_and_time :: proc() -> (gmtDate: string, hour: string, minute: string, second: string) {
	h, min, s := time.clock(time.now())
	y, m, d := time.date(time.now())

	mAsInt := int(m) //month comes back as a type "Month" so need to convert
	// Conversions!!! because everything in Odin needs to be converted... :)

	Y := int(y)
	M := int(m)
	D := int(d)

	H := int(h)
	MIN := int(min)
	S := int(s)

	Month := fmt.tprintf("%d", M)
	Year := fmt.tprintf("%d", Y)
	Day := fmt.tprintf("%d", D)

	Hour := fmt.tprintf("%d", H)
	Minute := fmt.tprintf("%d", MIN)
	Second := fmt.tprintf("%d", S)

	switch (mAsInt)
	{
	case 1:
		Month = "January"
		break
	case 2:
		Month = "February"
		break
	case 3:
		Month = "March"
		break
	case 4:
		Month = "April"
		break
	case 5:
		Month = "May"
		break
	case 6:
		Month = "June"
		break
	case 7:
		Month = "July"
		break
	case 8:
		Month = "August"
		break
	case 9:
		Month = "September"
		break
	case 10:
		Month = "October"
		break
	case 11:
		Month = "November"
		break
	case 12:
		Month = "December"
		break
	}

	Date := strings.concatenate([]string{Month, " ", Day, " ", Year, " "})

	return strings.clone(Date), strings.clone(Hour), strings.clone(Minute), strings.clone(Second)
}


//helper used to append qoutation marks to the beginning and end of a string record values
//if the value already has qoutation marks then it will not append them
@(require_results)
append_qoutations :: proc(value: string) -> string {
	if strings.contains(value, "\"") {
		return strings.clone(value)
	}
	return strings.clone(fmt.tprintf("\"%s\"", value))
}

//helper used to append single qoutation marks to the beginning and end of CHAR record values
@(cold, require_results)
append_single_qoutations_string :: proc(value: string) -> string {
	if strings.contains(value, "'") {
		return strings.clone(value)
	}
	return strings.clone(fmt.tprintf("'%s'", value))
}

@(cold, require_results)
append_single_qoutations_rune :: proc(value: rune) -> string {
	return strings.clone(fmt.tprintf("'%c'", value))
}

@(cold, require_results)
trim_qoutations :: proc(value: string) -> string {
	if strings.contains(value, "\"") {
		return strings.clone(strings.trim(value, "\""))
	}
	return strings.clone(value)
}


//helper used to strip array brackets from a string, used in internal_conversion.odin
@(cold, require_results)
strip_array_brackets :: proc(value: string) -> string {
	value := strings.trim_prefix(value, "[")
	value = strings.trim_suffix(value, "]")
	return strings.clone(strings.trim_space(value))
}

contains_disallowed_chars :: proc(input: string) -> bool {
    pattern, regexCompileError := regex.create(DISALLOWED_CHARS_PATTERN)
    if regexCompileError != nil {
        return false
    }
    defer regex.destroy(pattern)

    _, matchFound := regex.match(pattern, input) //this returns a capture and idk wtf that is so ignoring - Marshall
    if matchFound {
        return true
    }

    return false
}
