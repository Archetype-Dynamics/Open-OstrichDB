package projects

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:math/rand"
import "core:encoding/json"
import "../data"
import "../../config"
import lib"../../../library"
import "../users"
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
                Project related procedures and logic
*********************************************************/

CollectionInfo :: struct {
    name: string,
    createdAt: string,
    lastModified: string,
    size: string,
}

//Creates a project library...All this is, is the `projects` dir that all projects are located within
@(require_results)
make_new_project_library:: proc() -> ^lib.ProjectLibraryContext{
    using config
    projectLibraryContext := new(lib.ProjectLibraryContext)
    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }
    projectLibraryContext.basePath = currentOstrichPathConfig.projectBasePath

    return projectLibraryContext
}

// Create a new individual project context
make_new_project_context :: proc(userID: string, projectName: string, projectID: string = "") -> ^lib.ProjectContext {
    using config
    using fmt

    projectContext := new(lib.ProjectContext)
    projectContext.userID = userID
    projectContext.projectName = projectName
    projectIDClone:= generate_project_id()
    projectContext.projectID = projectIDClone
    projectContext.environment = get_environment()

    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    if len(userID) == 0 {
        users.log_error_event(users.make_new_user(""), &lib.ErrorEvent{
            severity = .ERROR,
            description = "userID is required for project context creation",
            type = .CREATE_OPERATION,
            timestamp = lib.get_current_time()
        })
        fmt.println("ERROR: userID is required for project context creation")
        free(projectContext)
        return nil
    }

    // Build user-isolated path: ./{userID}/projects/{projectName}/
    projectContext.basePath = fmt.tprintf("%s%s/projects/%s/",
        currentOstrichPathConfig.projectBasePath,  // ./
        userID,                                    // test_user_123/
        projectContext.projectName)                // my-cool-project/

    return projectContext
}

// Generate a unique project ID
@(require_results)
generate_project_id :: proc() -> string {
    timestamp := time.now()._nsec
    random := rand.int63_max(9999)
    return strings.clone(fmt.tprintf("proj_%d_%d", timestamp, random))
}

@(require_results)
init_project_structure :: proc(projectContext: ^lib.ProjectContext) -> bool {
    using lib
    using fmt
    using config

    if len(projectContext.userID) == 0 {
        users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = "Cannot initialize project structure without userID",
            type = .CREATE_OPERATION,
            timestamp = lib.get_current_time()
        })
        fmt.println("ERROR: Cannot initialize project structure without userID")
        return false
    }

    // Ensure user directory structure exists first
    if !user_directory_exists(projectContext.userID) {
        if !create_user_directory_structure(projectContext.userID) {
            users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
                severity = .ERROR,
                description = fmt.tprintf("Failed to create user directory structure for user: %s", projectContext.userID),
                type = .CREATE_OPERATION,
                timestamp = lib.get_current_time()
            })
            fmt.printf("ERROR: Failed to create user directory structure for user: %s\n", projectContext.userID)
            return false
        }
        fmt.printf("Created user directory structure for: %s\n", projectContext.userID)
    }

    success := true

    // Create project-specific directories within user's space
    directories := []string{
        projectContext.basePath,                                      // ./{userID}/projects/{projectName}/
        fmt.tprintf("%scollections/", projectContext.basePath),       // ./{userID}/projects/{projectName}/collections/
        fmt.tprintf("%sbackups/", projectContext.basePath),           // ./{userID}/projects/{projectName}/backups/
        fmt.tprintf("%stemp/", projectContext.basePath),              // ./{userID}/projects/{projectName}/temp/
    }

    for dir in directories {
        if os.make_directory(dir, FILE_MODE_EXECUTABLE) != 0 {
            users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
                severity = .ERROR,
                description = fmt.tprintf("Failed to create directory: %s", dir),
                type = .CREATE_OPERATION,
                timestamp = lib.get_current_time()
            })
            success = false
        }
    }

    // Create the projects metadata file and save info to it
    if success {
        metadata := lib.ProjectMetadata{
            projectID = projectContext.projectID,
            projectName = projectContext.projectName,
            userID = projectContext.userID,
            createdAt = time.now(),
            version = "1.0",
        }
        success = save_project_metadata(projectContext, &metadata)
    }

    return success
}

get_collections_path:: proc(projectContext: ^lib.ProjectContext) -> string {
    return strings.clone(fmt.tprintf("%scollections/", projectContext.basePath))
}

// Save project metadata
@(require_results)
save_project_metadata :: proc(projectContext: ^lib.ProjectContext, metadata: ^lib.ProjectMetadata) -> bool {

    metadataPath := fmt.tprintf("%s/project.json", projectContext.basePath)

    jsonData, marshalError := json.marshal(metadata^)
    if marshalError != nil {
        users.log_error_event(users.make_new_user(metadata.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = "Failed to marshal project metadata to JSON",
            type = .CREATE_OPERATION,
            timestamp = lib.get_current_time()
        })
        return false
    }
    defer delete(jsonData)

    return os.write_entire_file(metadataPath, jsonData)
}

// Load project metadata
@(require_results)
load_project_metadata :: proc(projectContext: ^lib.ProjectContext) -> (lib.ProjectMetadata, bool) {

    metadataPath := fmt.tprintf("%sproject.json", projectContext.basePath)

    data, readMetadataSuccess := os.read_entire_file(metadataPath)
    if !readMetadataSuccess {
        users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = fmt.tprintf("Failed to read project metadata file: %s", metadataPath),
            type = .READ_OPERATION,
            timestamp = lib.get_current_time()
        })
        return {}, false
    }
    defer delete(data)

    metadata: lib.ProjectMetadata
    unmarshalError := json.unmarshal(data, &metadata)
    if unmarshalError != nil {
        users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = "Failed to unmarshal project metadata from JSON",
            type = .READ_OPERATION,
            timestamp = lib.get_current_time()
        })
        return {}, false
    }

    return metadata, true
}

// Verify that the user has access to the passed in project context
@(require_results)
verify_project_access :: proc(projectContext: ^lib.ProjectContext, userID: string) -> bool {
    // Check if project exists and user owns it
    metadata, load_ok := load_project_metadata(projectContext)
    if !load_ok {
        return false
    }

    return metadata.userID == userID
}

//Lists all projects that a user can access. Project library is just the dir that projects are in..just needed a name for it.
@(require_results)
list_projects :: proc(projectLibrary: ^lib.ProjectLibraryContext, userID: string = "") -> ([]string, bool) {
    projects := make([dynamic]string)

    if len(userID) == 0 {
        users.log_error_event(users.make_new_user(""), &lib.ErrorEvent{
            severity = .ERROR,
            description = "userID is required for listing projects",
            type = .READ_OPERATION,
            timestamp = lib.get_current_time()
        })
        fmt.println("ERROR: userID is required for listing projects")
        return projects[:], false
    }

    userProjectPath := fmt.tprintf("%s%s/projects/", projectLibrary.basePath, userID)

    dir, openError := os.open(userProjectPath)
    if openError != 0 {
        // User directory doesn't exist yet - return empty list (not an error)
        return projects[:], true
    }
    defer os.close(dir)

    entries, readError := os.read_dir(dir, -1)
    // defer os.file_info_slice_delete(entries) <----Fixes mem leak but breaks code..... FUCK
    if readError != nil {
        return projects[:], false
    }

    for entry in entries {
        if entry.is_dir {
            // Verify this is a valid project by checking for project.json
            metadataPath := fmt.tprintf("%s%s/project.json", userProjectPath, entry.name)
            if _, stat_err := os.stat(metadataPath); stat_err == 0 {
                append(&projects, entry.name)
            }
        }
    }

    return projects[:], true
}

//returns a list of all collections within a projects context
@(require_results)
list_collections_in_project :: proc(projectContext: ^lib.ProjectContext) -> ([]string, bool) {
    using lib

    collectionPath := fmt.tprintf("%scollections/", projectContext.basePath)

    collections := make([dynamic]string)

    dir, openError := os.open(collectionPath)
    if openError != 0 {
        return collections[:], false
    }
    defer os.close(dir)

    entries, read_err := os.read_dir(dir, -1)
    defer os.file_info_slice_delete(entries)
    if read_err != nil {
        return collections[:], false
    }

    for entry in entries {
        if strings.has_suffix(entry.name, OST_EXT) {
            collection_name := strings.trim_suffix(entry.name, OST_EXT)
            append(&collections, collection_name)
        }
    }

    return collections[:], true
}

@(require_results)
erase_project :: proc(projectContext: ^lib.ProjectContext) -> bool {
    projectPath := projectContext.basePath

    // Recursively delete directory contents
    if !delete_directory_recursive(projectPath) {
        return false
    }

    // Now remove the project directory itself
    removeSuccess := lib.remove_dir(projectPath)
    if !removeSuccess {
        fmt.println("Could not remove project directory:", projectPath)
        return false
    }

    return true
}

//Helper procto recursively delete directory contents
delete_directory_recursive :: proc(dirPath: string) -> bool {
    projectDir, openDirError := os.open(dirPath)
    if openDirError != 0 {
        fmt.println("Could not open directory:", dirPath)
        return false
    }
    defer os.close(projectDir)

    items, readDirError := os.read_dir(projectDir, -1)
    defer os.file_info_slice_delete(items)
    if readDirError != 0 {
        fmt.println("Could not read directory:", dirPath)
        return false
    }

    // Process all items in the directory
    for item in items {
        if item.is_dir {
            // Recursively delete subdirectory contents first
            if !delete_directory_recursive(item.fullpath) {
                return false
            }
            removeSuccess := lib.remove_dir(item.fullpath)
            if !removeSuccess {
                fmt.println("Could not remove dir:", item.fullpath)
                return false
            }
            continue
        }

        // Delete the item (file or now-empty directory)
        removeSuccess := lib.remove_file(item.fullpath)
        if !removeSuccess {
            fmt.println("Could not remove item:", item.fullpath)
            return false
        }
    }

    return true
}



// In projects.odin - Updated function to return collections with info
@(require_results)
list_collections_in_project_with_info :: proc(projectContext: ^lib.ProjectContext) -> ([]CollectionInfo, bool) {
    using lib
    using data
    using fmt

    collectionPath := get_collections_path(projectContext)
    defer delete(collectionPath)
    collectionsData := make([dynamic]CollectionInfo)

    dir, openError := os.open(collectionPath)
    if openError != 0 {
        return collectionsData[:], false
    }
    defer os.close(dir)

    entries, read_err := os.read_dir(dir, -1)
    defer os.file_info_slice_delete(entries)
    if read_err != nil {
        return collectionsData[:], false
    }

    for entry in entries {
        if strings.has_suffix(entry.name, OST_EXT) {
            collection_name := strings.trim_suffix(entry.name, OST_EXT)

            collection := make_new_collection(collection_name, .STANDARD)
            defer free(collection)

            //Set defaults to use if the below proc calls fail
            createdAt := "Unknown"
            lastModified := "Unknown"
            size := "Unknown"

            //Get the Collections creation date from the metadata header
            if createdAtValue, err := get_metadata_field_value(projectContext, collection, "Date of Creation"); err == nil {
                createdAt = createdAtValue
                delete(createdAtValue)
            }

            //Get the Collections date last modified from the metadata header
            if lastModifiedValue, err := get_metadata_field_value(projectContext, collection, "Date Last Modified"); err == nil {
                lastModified = lastModifiedValue
                delete(lastModifiedValue)
            }

            //Get the Collections size from the metadata header. See below comment
            sizeValue, error := get_metadata_field_value(projectContext, collection, "File Size")
            if error == nil{
                size = sizeValue
            }

            //So for some reason this delete() call could not be in the scop of the above 'if' block.
            // If it was then the file 'size' value would be completly incorrect. Not only that, It has to be defered
            // I dont understand it... If anyone knows why be my guest - Marshall
            defer delete(sizeValue)

            collectionData := CollectionInfo{
                name = strings.clone(collection_name),
                createdAt = strings.clone(createdAt),
                lastModified = strings.clone(lastModified),
                size = strings.clone(size),
            }
            append(&collectionsData, collectionData)
        }
    }

    return collectionsData[:], true
}

@(require_results)
rename_project ::proc(projectContext: ^lib.ProjectContext, newPath:string) -> ^lib.Error{
    using lib
    using config


    if !lib.rename_file(projectContext.basePath, newPath) {
        users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = fmt.tprintf("Failed to rename project from %s to %s", projectContext.basePath, newPath),
            type = .UPDATE_OPERATION,
            timestamp = lib.get_current_time()
        })
        return make_new_err(.PROJECT_CANNOT_RENAME, get_caller_location())
    }

    return no_error()
}
