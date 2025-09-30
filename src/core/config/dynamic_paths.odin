package config

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:math/rand"
import "core:encoding/json"
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
            Dynamic path management for user projects and collections.
            Supports multi-tenant project structure for webapp backend.
*********************************************************/

// Global path config instance
currentOstrichPathConfig: ^lib.DynamicPathConfig

//Initialized the dynamic path system for this instance of OstrichDB
@(require_results)
init_dynamic_paths :: proc(environment: string = "") -> ^lib.DynamicPathConfig {
    using fmt

    env := environment if environment != "" else get_environment()

    config := new(lib.DynamicPathConfig)

    switch env {
    case "production":
        config.rootPath = "/var/lib/ostrichdb/"
        config.projectBasePath = "/var/lib/ostrichdb/"
        config.systemBasePath = "/var/lib/ostrichdb/system/"
        config.logBasePath = "/var/log/ostrichdb/"
        config.tempBasePath = "/tmp/ostrichdb/"

    case "development":
        fallthrough
    case:
        config.rootPath = "./"
        config.projectBasePath = "./"
    }

    //Make sure base directories exist
    create_base_directories(config)

    currentOstrichPathConfig = config
    return config
}

@(require_results)
create_user_directory_structure :: proc(userID: string) -> bool {
    using fmt
    using lib

    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    success := true

    // Create user's directory structure: {root}/{userID}/
    userBasePath := fmt.tprintf("%s%s/", currentOstrichPathConfig.projectBasePath, userID)

    userDirectories := []string{
        userBasePath,                                    // ./{userID}/
        fmt.tprintf("%sprojects/", userBasePath),        // ./{userID}/projects/
        fmt.tprintf("%stmp/", userBasePath),             // ./{userID}/tmp/
        fmt.tprintf("%slogs/", userBasePath),            // ./{userID}/logs/
    }

    for dir in userDirectories {
        result := os.make_directory(dir, FILE_MODE_EXECUTABLE)
        if result != 0 {
            success = false
        }
    }

    return success
}

// Check if user directory structure exists
@(require_results)
user_directory_exists :: proc(userID: string) -> bool {
    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    userBasePath := fmt.tprintf("%s%s/", currentOstrichPathConfig.projectBasePath, userID)

    // Check if the user's projects directory exists
    userProjectsPath := fmt.tprintf("%sprojects/", userBasePath)

    if _, stat_err := os.stat(userProjectsPath); stat_err == 0 {
        return true
    }

    return false
}

// Get user-specific paths
@(require_results)
get_user_paths :: proc(userID: string) -> lib.UserPathConfig {
    using fmt

    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    userBasePath := fmt.tprintf("%s%s/", currentOstrichPathConfig.projectBasePath, userID)

    return lib.UserPathConfig{
        userID = userID,
        basePath = userBasePath,
        projectsPath = fmt.tprintf("%sprojects/", userBasePath),
        backupsPath = fmt.tprintf("%sbackups/", userBasePath),
        logsPath = fmt.tprintf("%slogs/", userBasePath),
        tempPath = fmt.tprintf("%stmp/", userBasePath),
    }
}

//Create base directory and its immediate sub-dirs
create_base_directories :: proc(config: ^lib.DynamicPathConfig) {
    using lib
    directories := []string{
        config.rootPath,
        config.systemBasePath,
        config.logBasePath,
        config.tempBasePath,
    }

    for dir in directories {
        os.make_directory(dir, FILE_MODE_EXECUTABLE)
    }
}

// Cleanup function
cleanup_dynamic_paths :: proc() {
    if currentOstrichPathConfig != nil {
        free(currentOstrichPathConfig)
        currentOstrichPathConfig = nil
    }
}