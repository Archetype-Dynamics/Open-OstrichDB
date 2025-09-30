package server

import "core:fmt"
import "core:strings"
import "../config"
import "../engine/projects"
import "../engine/data"
import "../engine/security"
import lib"../../library"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB

Contributors:

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
All Rights Reserved.

This software is proprietary and confidential. Unauthorized copying,
distribution, modification, or use of this software, in whole or in part,
is strictly prohibited without the express written permission of
Archetype Dynamics, Inc.

File Description:
            Contains logic for handling operations securely meaning encryption
            and decryption before and after operations
*********************************************************/



// Extract project context from request path
@(require_results)
extract_project_context :: proc(path: string, headers: map[string]string) -> (^lib.ProjectContext, bool) {
    using strings
    using projects
    using config

    // Expected format: /api/v1/projects/{project_name}/...
    segments := split_path_into_segments(path)

    if len(segments) < 3 || segments[0] != "api" || segments[1] != "v1" || segments[2] != "projects" {
        return nil, false
    }

    // For route: /api/v1/projects - we still need userID for listing
    if len(segments) == 3 {
        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return nil, false
        }

        // Create a minimal project context just for project listing
        projectContext := make_new_project_context(userID, "", "")
        return projectContext, true
    }

    if len(segments) < 4 {
        return nil, false
    }

    projectName := segments[3]

    userID, authenticated := require_authentication(headers)
    if !authenticated || userID == "" {
        return nil, false
    }

    if !user_directory_exists(userID) {
        if !create_user_directory_structure(userID) {
            fmt.printf("ERROR: Failed to create user directory for: %s\n", userID)
            return nil, false
        }
        fmt.printf("INFO: Created user directory structure for new user: %s\n", userID)
    }

    // Create project context with user isolation
    projectContext := make_new_project_context(userID, projectName)
    if projectContext == nil {
        return nil, false
    }

    // Verify project access
    if !verify_project_access(projectContext, userID) {
        fmt.printf("ERROR: User %s does not have access to project %s\n", userID, projectName)
        free(projectContext)
        return nil, false
    }

    return projectContext, true
}

//Collective proc of the below proces
@(private)
secure_collection_operation :: proc{
    secure_collection_operation_basic,
    secure_collection_operation_with_cluster,
    secure_collection_operation_with_cluster_and_record,
    secure_collection_operation_with_cluster_and_path,
    secure_collection_operation_with_cluster_record_and_query,
    secure_collection_operation_with_query_params,
    secure_collection_operation_with_cluster_and_query_params,
}

//Helper proc that checks encryption state of collection, decrypts, performs desired operation, then re-encrypts
@(private)
secure_collection_operation_basic :: proc(projectContext: ^lib.ProjectContext, collectionName: string, operation: proc(^lib.ProjectContext, ^lib.Collection) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        //If the encryption state metadata field isnt read then assume its NOT encrypted
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        decryptedData, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"

    }

    free_all()
    return make_new_http_status(.OK, HttpStatusText[.OK]), result
}

//Note: The following helper procedures are needed to decrypt a Collection before performing opertations on "lower tier" data structures - Marshall

//Collection + Cluster operations
@(private)
secure_collection_operation_with_cluster :: proc(projectContext: ^lib.ProjectContext, collectionName: string, clusterName: string, operation: proc(^lib.ProjectContext, ^lib.Collection, ^lib.Cluster) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Create cluster
    cluster := make_new_cluster(collection, clusterName)

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        _, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection, cluster)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"
    }

    free_all()
    return make_new_http_status(.OK, HttpStatusText[.OK]), result
}

//Collection + Cluster + Record operations
@(private)
secure_collection_operation_with_cluster_and_record :: proc(projectContext: ^lib.ProjectContext, collectionName: string, clusterName: string, recordName: string, operation: proc(^lib.ProjectContext, ^lib.Collection, ^lib.Cluster, ^lib.Record) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Create cluster and record
    cluster := make_new_cluster(collection, clusterName)
    record := make_new_record(collection, cluster, recordName)

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        _, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection, cluster, record)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"
    }

    free_all()
    return make_new_http_status(.OK, HttpStatusText[.OK]), result
}

//Collection + Cluster operations with query parameters
@(private)
secure_collection_operation_with_cluster_and_path :: proc(projectContext: ^lib.ProjectContext, collectionName: string, clusterName: string, requestPath: string, operation: proc(^lib.ProjectContext, ^lib.Collection, ^lib.Cluster, string) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)
    // defer free(collection)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Create cluster
    cluster := make_new_cluster(collection, clusterName)

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        _, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection, cluster, requestPath)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"
    }

    free_all()
    return make_new_http_status(.OK, HttpStatusText[.OK]), result
}

//Collection + Cluster + Record operations with query parameters
@(private)
secure_collection_operation_with_cluster_record_and_query :: proc(projectContext: ^lib.ProjectContext, collectionName: string, clusterName: string, recordName: string, queryParams: map[string]string, operation: proc(^lib.ProjectContext, ^lib.Collection, ^lib.Cluster, ^lib.Record, map[string]string) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Create cluster and record
    cluster := make_new_cluster(collection, clusterName)
    record := make_new_record(collection, cluster, recordName)

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        _, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection, cluster, record, queryParams)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"
    }

    free_all()
    return make_new_http_status(.CREATE, HttpStatusText[.CREATE]), result
}

//Collection operations with query parameters e.g: Renaming
@(private)
secure_collection_operation_with_query_params :: proc(projectContext: ^lib.ProjectContext, collectionName: string, queryParams: map[string]string, operation: proc(^lib.ProjectContext, ^lib.Collection, map[string]string) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        _, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection, queryParams)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"
    }

    free_all()
    return make_new_http_status(.OK, HttpStatusText[.OK]), result
}

//Collection + Cluster operations with query parameters e.g: Renaming
@(private)
secure_collection_operation_with_cluster_and_query_params :: proc(projectContext: ^lib.ProjectContext, collectionName: string, clusterName: string, queryParams: map[string]string, operation: proc(^lib.ProjectContext, ^lib.Collection, ^lib.Cluster, map[string]string) -> (string, ^lib.Error)) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using security

    collection := make_new_collection(collectionName, .STANDARD)

    // Check if collection exists
    exists, _ := check_if_collection_exists(projectContext, collection)
    if !exists {
        return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
               fmt.tprintf("Collection %s not found\n", collectionName)
    }

    // Create cluster
    cluster := make_new_cluster(collection, clusterName)

    // Get encryption state
    encState, stateErr := get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        encState = "0"
    }

    isEncrypted := encState == "1"

    // If the collection is indeed encrypted, decrypt before do the operation
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to get encryption key\n"
        }
        defer clear_key_from_memory(masterKey)

        _, decErr := decrypt_collection(projectContext, collection, masterKey)
        if decErr != nil {
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Failed to decrypt collection: %s\n"
        }
    }

    // Perform the operation
    result, operationError := operation(projectContext, collection, cluster, queryParams)

    // Re-encrypt
    if isEncrypted {
        masterKey, keyErr := get_user_master_key(projectContext.userID)
        if keyErr == nil {
            defer clear_key_from_memory(masterKey)
            encrypt_collection(projectContext, collection, masterKey)
        }
    }

    if operationError != nil {
        return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),"Operation failed\n"
    }

    free_all()
    return make_new_http_status(.OK, HttpStatusText[.OK]), result
}
