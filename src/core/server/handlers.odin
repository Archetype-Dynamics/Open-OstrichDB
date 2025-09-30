package server

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:strconv"
import "core:encoding/json"
import "core:encoding/base64"
import "../config"
import "../engine/data"
import lib "../../library"
import "../engine/projects"
import "../engine/security"
import "../engine/users"
import "../engine/queries"
/********************************************************
Author: Marshall A Burns
GitHub: @SchoolyB

Contributors:
                    @CobbCoding1

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
All Rights Reserved.

This software is proprietary and confidential. Unauthorized copying,
distribution, modification, or use of this software, in whole or in part,
is strictly prohibited without the express written permission of
Archetype Dynamics, Inc.

File Description:
            Contains logic for handling requests from the client.
            All handlers expected to follow the `RouteHandler` procedure signature
            found in types.odin Note: Unstable and not fully implemented.
*********************************************************/


/********************************************************
The handlers in this file handle the following routes:
- /health
- /version
- /api/v1/projects/
- /api/v1/projects/{project_name}
- /api/v1/projects/{project_name}/collections
- /api/v1/projects/{project_name}/collections/{collectionName}
- /api/v1/projects/{project_name}/collections/{collectionName}/clusters
- /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}
- /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}/records
- /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}/records/{record_id}
- /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}/records/{record_name}
    As well as Searching, Sorting, and Filtering Queries for Records

If new endpoints or handlers are added, be sure to add them above :) - Marshall
*********************************************************/

//This proc is a great template on how the remaining request handling procedure will generally work
//Note: See all comments to help understand flow of this proc
handle_get_request:: proc(method: lib.HttpMethod, path: string, headers: map[string]string, args: []string = {""}) -> (^lib.HttpStatus, string) {
    using lib
    using data
    using fmt
    using strings

    if method != .GET {
        return make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST]), "Request Failed: Method not allowed\n"
    }

    appConfig := config.get_config()
    userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)

    if !authenticated {
        return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
    }

    if rateLimited {
        return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
    }

    segments := split_path_into_segments(path)
    numberOfSegments := len(segments)

    //Route: /api/v1/user/{user_id}/logs/*
    // if numberOfSegments == 6 && segments[2] == "user" && segments[4] == "logs"{
    if numberOfSegments == 6 && segments[2] == "user" && segments[4] == "logs"{

        userID, authenticated := require_authentication(headers)
        currentUser:= users.make_new_user(userID)

        logType: users.LOG_TYPE
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        switch(segments[5]){
            case "errors":
                logType = .ERROR
                break
            case "server":
                logType = .SERVER
                break
        }

        logData, getLogError:= users.get_user_log(currentUser, logType)
        if getLogError != nil {
            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Failed to fetch user %s logs", segments[5]),
            ServerEventType.ERROR, time.now(), true, "/api/v1/user/*/logs", .GET,))
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: Unable to get %s logs at this time.\n", segments[5])
        }

        users.log_user_server_event(currentUser, users.make_new_server_event(
        fmt.tprintf("Successfully fetched user %s logs", segments[5]),
        ServerEventType.SUCCESS, time.now(), true, "/api/v1/user/*/logs", .GET,))
        return make_new_http_status(.OK, HttpStatusText[.OK]), string(logData)
    }

    // Extract project context
    projectContext, projectContextOK := extract_project_context(path, headers)
    if !projectContextOK {
        return make_new_http_status(.CONFLICT, HttpStatusText[.CONFLICT]), "Request Failed: Unauthorized or invalid project\n"
    }

    // Route: /api/v1/projects
    // Used to return a list of all projects names
    if numberOfSegments == 3 {
        // Require authentication for project listing
        userID, authenticated := require_authentication(headers)
        currentUser:= users.make_new_user(userID)

        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        // Check if user directory exists
        userDirExists := config.user_directory_exists(userID)

        // Ensure user directory structure exists before listing projects
        if !userDirExists {
            if !config.create_user_directory_structure(userID) {
                return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), "Request Failed: Unable to create user directory\n"
            }
        }

        projectLibrary := projects.make_new_project_library()
        // defer free(projectLibrary)

        // Only list projects for the authenticated user
        projectsList, success := projects.list_projects(projectLibrary, userID)
        if !success {
            users.log_user_server_event(currentUser, users.make_new_server_event(
            "Failed to fetch users owned Projects",
            ServerEventType.ERROR, time.now(), true, "/api/v1/projects", .GET,))
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), "Request Failed: Failed to list projects\n"
        }
        // defer delete(projectsList)

        if len(projectsList) == 0 {
            response := fmt.tprintf(`%s"user_id": "%s"%s`, "{", userID, "}")
            users.log_user_server_event(currentUser, users.make_new_server_event(
            "Successfully fetched Projects, but none were found",
            ServerEventType.SUCCESS, time.now(), true, "/api/v1/projects", .GET,))
            return make_new_http_status(.OK, HttpStatusText[.OK]), response
        }

        projectsJson := make([dynamic]string)
        // defer delete(projectsJson)

        for project in projectsList {
            projectJson := fmt.tprintf(`"%s"`, project)
            append(&projectsJson, projectJson)
        }

        // Format as JSON response with comma separation
        response := fmt.tprintf(`%s"projects": [%s], "user_id": "%s"%s`, "{",
        strings.join(projectsJson[:], ", "), userID, "}")


        users.log_user_server_event(currentUser, users.make_new_server_event(
        "Successfully fetched projects",
        ServerEventType.SUCCESS, time.now(), true, "/api/v1/projects", .GET,))
        return make_new_http_status(.OK, HttpStatusText[.OK]), response
    }


    if numberOfSegments == 5 && segments[4] == "collections" {
        userID, authenticated := require_authentication(headers)
        currentUser:= users.make_new_user(userID)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionsData, success := projects.list_collections_in_project_with_info(projectContext)
        // defer delete(collectionsData)
        if !success{
            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Failed to fetch collections in Project: %s", projectContext.projectName),
            ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections", projectContext.projectName), .GET,))
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),  fmt.tprintf("Request Failed: Failed to fetch Collections in Project: %s\n", projectContext.projectName)
        }

        if len(collectionsData) == 0 {
            emptyResponse := fmt.tprintf("%s\"collections\": [], \"message\": \"No collections found\"%s", "{", "}")
            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Successfully fetched Collections in Project: %s but none were found", projectContext.projectName),
            ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections", projectContext.projectName), .GET,))
            return make_new_http_status(.OK, HttpStatusText[.OK]), emptyResponse
        }

        collectionsJson := make([dynamic]string)
        // defer delete(collectionsJson)

        for collectionData in collectionsData {
            // Clean each field and provide defaults for empty values
            safeName := clean_metadata_field(collectionData.name, "unnamed")
            safeCreatedAt := clean_metadata_field(collectionData.createdAt, "Unknown")
            safeLastModified := clean_metadata_field(collectionData.lastModified, "Unknown")
            safeSize := clean_metadata_field(collectionData.size, "Unknown")

            collectionJson := fmt.tprintf("%s\"name\": \"%s\", \"createdAt\": \"%s\", \"lastModified\": \"%s\", \"size\": \"%s\"%s",
                "{",
                safeName,
                safeCreatedAt,
                safeLastModified,
                safeSize,
                "}")
            append(&collectionsJson, collectionJson)

            delete(safeName)
            delete(safeCreatedAt)
            delete(safeLastModified)
            delete(safeSize)
        }

        response := fmt.tprintf("%s\"collections\": [%s]%s", "{", strings.join(collectionsJson[:], ", "), "}")
        users.log_user_server_event(currentUser, users.make_new_server_event(
        fmt.tprintf("Successfully fetched Collections in Project: %s", projectContext.projectName),
        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections", projectContext.projectName), .GET,))
        return make_new_http_status(.OK, HttpStatusText[.OK]), response
    }

    // Route: /api/v1/projects/{project_name}/collections/{collectionName}
    // Returns the contents of the specified collection
    if numberOfSegments == 6 && segments[4] == "collections" {
        userID, authenticated := require_authentication(headers)
        currentUser:= users.make_new_user(userID)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]

        //I know this may look a bit confusing or cluttered but the logic has been updated to add security.
        // If confused just read over the `secure_collection_operation` declaration at the top of the file - Marshall
          return secure_collection_operation(projectContext, collectionName,
              proc(projCTX: ^lib.ProjectContext, colName: ^lib.Collection) -> (string, ^lib.Error) {
                  currentUser:= users.make_new_user(projCTX.userID)
                  collection, fetchSuccess := fetch_collection(projCTX, colName)
                  if fetchSuccess != nil {
                      return "", fetchSuccess
                  }

                  if collection.body.isEmpty {
                      users.log_user_server_event(currentUser, users.make_new_server_event(
                      fmt.tprintf("Successfully fetched Collection: %s but no data was found", collection.name),
                      ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s", projCTX.projectName, collection.name), .GET,))
                      return fmt.tprintf("Request Successful: No Clusters found in Collection: %s\n", collection.name), no_error()
                  }

                  collectionJSON := fmt.tprintf(
                      "%s\"name\": \"%s\", \"cluster_count\": \"%d\", \"record_count\": \"%d\", \"size\": \"%d\"%s",
                      "{",
                      collection.name,
                      collection.body.clusterCount,
                      collection.body.recordCount,
                      collection.fileSize,
                      "}")

                  users.log_user_server_event(currentUser, users.make_new_server_event(
                  fmt.tprintf("Successfully fetched Collection: %s", collection.name),
                  ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s", projCTX.projectName, collection.name), .GET,))
                  return collectionJSON, no_error()
              })
    }

    // Route: /api/v1/projects/{project_name}/collections/{collectionName}/clusters
    // Used to return a JSON array of key Cluster information within a collection. Name, ID, Record count
    if numberOfSegments == 7 && segments[4] == "collections" && segments[6] == "clusters" {

        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]

        return secure_collection_operation(projectContext, collectionName,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection) -> (string, ^lib.Error) {
                clustersData, getClusterInfoError := get_all_clusters_info(projCTX, collection)

                currentUser:= users.make_new_user(projCTX.userID)
                if getClusterInfoError != nil {
                    return "", getClusterInfoError
                }

                if len(clustersData) == 0 {
                    users.log_user_server_event(currentUser, users.make_new_server_event(
                    fmt.tprintf("Successfully fetched Clusters within Collection: %s, but none were found", collection.name),
                    ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters", projCTX.projectName, collection.name), .GET,))
                    return fmt.tprintf("Request Successful: No Clusters found within Collection: %s\n", collection.name), no_error()
                }

                clustersDataJSON := make([dynamic]string)
                // defer delete(clustersDataJSON)

                for cluster in clustersData {
                    clusterJSON := fmt.tprintf("%s\"name\": \"%s\", \"id\": \"%d\", \"record_count\": \"%d\"%s",
                        "{",
                        cluster.name,
                        cluster.id,
                        cluster.recordCount,
                        "}")

                    append(&clustersDataJSON, clusterJSON)
                }

                response := fmt.tprintf("%s\"clusters\": [%s]%s", "{", strings.join(clustersDataJSON[:], ", "), "}")
                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Successfully fetched clusters within collection: %s", collection.name),
                ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters", projCTX.projectName,collection.name), .GET,))
                return response, no_error()
            })
    }

    // Route: /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}
    // Returns the contents of the specified cluster in the specified collection
    if numberOfSegments == 8 && segments[4] == "collections" && segments[6] == "clusters" {

        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]
        clusterName := segments[7]

        return secure_collection_operation(projectContext, collectionName, clusterName,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> (string, ^lib.Error) {
                // Parse the decrypted collection to find the cluster
                currentUser:= users.make_new_user(projCTX.userID)
                parsedCollection, parseError := parse_entire_collection(projCTX, collection)
                // defer free(&parsedCollection)

                if parseError != nil {
                    return "", parseError
                }

                // Find the specific cluster in the parsed collection
                for parsedCluster in parsedCollection.body.clusters {
                    if parsedCluster.name == cluster.name {
                        if parsedCluster.recordCount == 0 {
                            users.log_user_server_event(currentUser, users.make_new_server_event(
                            fmt.tprintf("Successfully fetched Records within Collection: %s Cluster: %s but none were found", collection.name, cluster.name),
                            ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s",projCTX.projectName, collection.name, cluster.name), .GET,))
                            return fmt.tprintf("Request Successful: But, no records found in Cluster: %s in Collection: %s \n", cluster.name, collection.name), no_error()
                        }

                        someNewRecord:= new(data.ParsedRecord)
                        // Build JSON response from parsed cluster data
                        jsonBuilder := strings.builder_make()
                        defer strings.builder_destroy(&jsonBuilder)

                        strings.write_string(&jsonBuilder, "{\n")
                        strings.write_string(&jsonBuilder, fmt.tprintf("  \"cluster_name\": \"%s\",\n", parsedCluster.name))
                        strings.write_string(&jsonBuilder, fmt.tprintf("  \"cluster_id\": %d,\n", parsedCluster.id))
                        strings.write_string(&jsonBuilder, fmt.tprintf("  \"record_count\": %d,\n", parsedCluster.recordCount))
                        strings.write_string(&jsonBuilder, "  \"records\": [\n")

                        for record, i in parsedCluster.records {
                            strings.write_string(&jsonBuilder, "    {\n")
                            strings.write_string(&jsonBuilder, fmt.tprintf("      \"name\": \"%s\",\n", record.name))
                            strings.write_string(&jsonBuilder, fmt.tprintf("      \"type\": \"%s\",\n", record.typeAsString))
                            strings.write_string(&jsonBuilder, fmt.tprintf("      \"value\": \"%s\"\n", record.value))
                            if i < len(parsedCluster.records) - 1 {
                                strings.write_string(&jsonBuilder, "    },\n")
                            } else {
                                strings.write_string(&jsonBuilder, "    }\n")
                            }
                            someNewRecord.name = record.name
                            someNewRecord.typeAsString = record.typeAsString
                            someNewRecord.value = record.value
                        }

                        strings.write_string(&jsonBuilder, "  ]\n")
                        strings.write_string(&jsonBuilder, "}")

                        users.log_user_server_event(currentUser, users.make_new_server_event(
                        fmt.tprintf("Successfully fetched Record: %s within Collection: %s Cluster: %s", someNewRecord.name,collection.name, cluster.name),
                        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s", projCTX.projectName,collection.name, cluster.name), .GET,))

                        free(someNewRecord)
                        return strings.clone(strings.to_string(jsonBuilder)), no_error()
                    }
                }

                return "", make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
            })
    }

    // Route: /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}/records{ / or ?}
    // Handles both filtered queries and record listing
    if numberOfSegments == 9 && segments[4] == "collections" && segments[6] == "clusters" && segments[8] == "records" {

        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]
        clusterName := segments[7]

        return secure_collection_operation(projectContext, collectionName, clusterName, path,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, requestPath: string) -> (string, ^lib.Error) {
                // Check if there are actual query parameters (not just "?")
                currentUser:= users.make_new_user(projCTX.userID)

                queryString := extract_query_from_path(requestPath)
                hasValidQueryParams := len(trim_space(queryString)) > 0 && contains(queryString, "=")

                if hasValidQueryParams {
                    // Handle filtering/searching with query parameters
                    queryParams := parse_query_params(queryString)

                    // Convert query params to search criteria
                    searchCriteria := query_params_to_search_criteria(queryParams)

                    // Get filtered and sorted records using the enhanced search
                    records, fetchSuccess := search_and_filter_records(
                        projCTX,
                        collection,
                        cluster,
                        searchCriteria,
                        queryParams.limit,
                        queryParams.offset
                    )
                    // defer delete(records)
                    if !fetchSuccess {
                        return "", make_new_err(.RECORD_CANNOT_FILTER, get_caller_location())
                    }

                    if len(records) == 0 {
                        emptyResponse := fmt.tprintf("%s\"records\": [], \"message\": \"No records found matching criteria\"%s", "{", "}")
                        users.log_user_server_event(currentUser, users.make_new_server_event(
                        fmt.tprintf("Successfully queried for Record, but no results were found"),
                        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records?", projCTX.projectName, collection.name, cluster.name), .GET,))

                        return emptyResponse, no_error()
                    }
                    someNewRecord:= new(data.ParsedRecord)
                    recordsDataJSON := make([dynamic]string)
                    // defer delete(recordsDataJSON)

                    for record in records {
                        // Clean each field to ensure safe JSON output
                        safeName := clean_metadata_field(record.name, "unnamed")
                        safeType := clean_metadata_field(record.typeAsString, "UNKNOWN")
                        safeValue := clean_metadata_field(record.value, "")

                        someNewRecord.name = safeName

                        recordJSON := fmt.tprintf("%s\"id\": \"%d\", \"name\": \"%s\", \"type\": \"%s\", \"value\": \"%s\"%s",
                            "{",
                            record.id,
                            safeName,
                            safeType,
                            safeValue,
                            "}")
                        append(&recordsDataJSON, recordJSON)

                        // Clean up allocated strings
                        delete(safeName)
                        delete(safeType)
                        delete(safeValue)
                    }

                    response := fmt.tprintf("%s\"records\": [%s]%s", "{", strings.join(recordsDataJSON[:], ", "), "}")
                    users.log_user_server_event(currentUser, users.make_new_server_event(
                    fmt.tprintf("Successfully queried for Record: %s", someNewRecord.name),
                    ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records?",projCTX.projectName, collection.name, cluster.name, someNewRecord.name ), .GET,))
                    return response, no_error()

                } else {
                    recordNames, fetchSuccess := get_all_record_names_in_cluster(projCTX, collection, cluster)
                    // defer delete(recordNames)

                    if fetchSuccess != nil {
                        return "", fetchSuccess
                    }

                    if len(recordNames) == 0 {
                        emptyResponse := fmt.tprintf("%s\"records\": [], \"message\": \"No records found\"%s", "{", "}")
                        return emptyResponse, no_error()
                    }

                    recordsDataJSON := make([dynamic]string)
                    // defer delete(recordsDataJSON)

                    // Fetch full record data for each record name

                    for recordName in recordNames {
                        someNewRecord := make_new_record(collection, cluster, recordName)
                        newRecord := make_new_record(collection, cluster, recordName)
                        record, recordFetchSuccess := fetch_record(projCTX, collection, cluster, newRecord)

                        if recordFetchSuccess == nil {
                            // Clean each field to ensure safe JSON output
                            safeName := clean_metadata_field(record.name, "unnamed")
                            safeType := clean_metadata_field(record.typeAsString, "UNKNOWN")
                            safeValue := clean_metadata_field(record.value, "")

                            someNewRecord.name = safeName

                            recordJSON := fmt.tprintf("%s\"id\": \"%d\", \"name\": \"%s\", \"type\": \"%s\", \"value\": \"%s\"%s",
                                "{",
                                record.id,
                                safeName,
                                safeType,
                                safeValue,
                                "}")
                            append(&recordsDataJSON, recordJSON)
                            delete(safeName)
                            delete(safeType)
                            delete(safeValue)
                        }

                        free(newRecord)
                        users.log_user_server_event(currentUser, users.make_new_server_event(
                        fmt.tprintf("Successfully queried for Record"),
                        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records%s",projCTX.projectName, collection.name, cluster.name, someNewRecord.name ), .GET,))
                    }

                    response := fmt.tprintf("%s\"records\": [%s]%s", "{", strings.join(recordsDataJSON[:], ", "), "}")
                    return response, no_error()
                }
            })
    }

    // Route: /api/v1/projects/{project_name}/collections/{collectionName}/clusters/{cluster_name}/records/{record_id_or_name}
    // Individual record access by ID or name
    if numberOfSegments == 10 && segments[4] == "collections" && segments[6] == "clusters" && segments[8] == "records" {
        userID, authenticated := require_authentication(headers)
        currentUser:= users.make_new_user(userID)

        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]
        clusterName := segments[7]
        recordIdentifier := segments[9]

        newCollection := make_new_collection(collectionName, .STANDARD)
        newCluster := make_new_cluster(newCollection, clusterName)
        // defer free(newCollection)
        // defer free(newCluster)

        // Try to parse as ID first (numeric)
        if recordID, ok := strconv.parse_i64(recordIdentifier); ok {
            // It's a numeric ID
            record, fetchSuccess := get_record_by_id(projectContext, newCollection, newCluster, recordID)
            if fetchSuccess != nil {

                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Failed to fetch record %d: ", record.id),
                ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%d", projectContext.projectName,collectionName, clusterName, record.id), .GET,))
                return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]),fmt.tprintf("Request Failed: Record with ID %d not found in Cluster: %s in Collection: %s\n", recordID, clusterName, collectionName)
            }

            if len(record.value) == 0 {
                return make_new_http_status(.PARTIAL_CONTENT, HttpStatusText[.PARTIAL_CONTENT]),
                       fmt.tprintf("Request Successful: Record found but no value assigned to Record ID: %d in Cluster: %s in Collection: %s\n", recordID, clusterName, collectionName)
            }

            // Return JSON format
            response := fmt.tprintf("%s\"id\": \"%d\", \"name\": \"%s\", \"type\": \"%s\", \"value\": \"%s\"%s",
                "{",
                recordID,
                record.name,
                record.typeAsString,
                record.value,
                "}")

            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Successfully fetched Record %d: ", record.id),
            ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%d", projectContext.projectName,collectionName, clusterName, record.id), .GET,))
            return make_new_http_status(.OK, HttpStatusText[.OK]), response
        } else {
            // It's a record name
            recordName := recordIdentifier
            newRecord := make_new_record(newCollection, newCluster, recordName)
            // defer free(newRecord)

            record, fetchSuccess := fetch_record(projectContext, newCollection, newCluster, newRecord)
            if fetchSuccess != nil {
                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Failed to fetch Record %s: ", record.name),
                ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s", projectContext.projectName,collectionName, clusterName, record.name), .GET,))
                return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]),
                       fmt.tprintf("Request Failed: Record '%s' not found in Cluster: %s in Collection: %s\n", recordName, clusterName, collectionName)
            }

            if len(record.value) == 0 {
                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Successfully fetched record: %s, but no value assigned ", record.name),
                ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s",projectContext.projectName, collectionName, clusterName, record.name), .GET,))
                return make_new_http_status(.PARTIAL_CONTENT, HttpStatusText[.PARTIAL_CONTENT]),
                       fmt.tprintf("Request Successful: Record found but no value assigned to Record: %s in Cluster: %s in Collection: %s\n", recordName, clusterName, collectionName)
            }

            // Get the record ID for display
            recordID, incrementError := increment_record_id(projectContext, newCollection, newCluster)

            if incrementError != nil{
                return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: Could Not Update Increment ID for Record '%s' in Cluster: %s in Collection: %s\n", recordName, clusterName, collectionName)
            }

            // Return JSON format
            response := fmt.tprintf("%s\"id\": \"%d\", \"name\": \"%s\", \"type\": \"%s\", \"value\": \"%s\"%s",
                "{",
                recordID,
                record.name,
                record.typeAsString,
                record.value,
                "}")

            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Successfully fetched Record: %s", record.name),
            ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s",projectContext.projectName, collectionName, clusterName, record.name), .GET,))
            return make_new_http_status(.OK, HttpStatusText[.OK]), response
        }
    }

    newHTTPStatus := make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND])
    return newHTTPStatus, "Not Found\n"
}

handle_post_request:: proc(method: lib.HttpMethod, path: string, headers: map[string]string, args: []string) -> (^lib.HttpStatus, string) {
   using lib
   using data
   using fmt

   if method != .POST {
       return make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST]), fmt.tprintf("Request Failed: Method not allowed\n")
   }

   segments := split_path_into_segments(path)

   if len(segments) == 4 && segments[0] == "api" && segments[1] == "v1" && segments[2] == "projects"  {

       appConfig := config.get_config()
       userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)

       if !authenticated {
           return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
       }

       if rateLimited {
           return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
       }


       if len(segments[3]) != 0{
           args[0] = segments[3]
           return handle_create_project(headers, args)
       }
       return make_new_http_status(.CONFLICT, HttpStatusText[.CONFLICT]), fmt.tprintf("Request Failed: Missing project name\n")
   }

   appConfig := config.get_config()
   userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)
   currentUser:= users.make_new_user(userID)

   if !authenticated {
       return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
   }

   if rateLimited {
       return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
   }

   projectContext, projectContextOK := extract_project_context(path, headers)
   if !projectContextOK {
       return make_new_http_status(.CONFLICT, HttpStatusText[.CONFLICT]), fmt.tprintf("Request Failed: Unauthorized or invalid project\n")
   }

   numberOfSegments := len(segments)

   //Route: /api/v1/projects/{projectID}/manual_query?value={query}
   //Note:  This logic is only used to create a valid endpoint to then send it back to the requestor
   //            which will then use the valid endpoint to make a proper DB operation request to the server
   if numberOfSegments == 5  && segments[2] == "projects" && segments[4] == "manual_query"{

       valueSegmentSplit:= strings.split(path, "?")
       queryValue:= strings.split(valueSegmentSplit[1],"value=")
        sanitizedQuery, _:= strings.replace(queryValue[1], "%20", " ", -1) //clean up the value

       query, queryParseError := queries.parse_query(sanitizedQuery)
       if queryParseError != nil do return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), "Failed to parse query"
       constructedEndpoint:= queries.query_to_endpoint_constructor(projectContext, query)

       payload:= make_manual_query_payload(query, constructedEndpoint)

       response := fmt.tprintf("%s\"method\": \"%s\", \"path\": \"%s\"%s",
               "{",
               payload.methodStr,
               payload.path,
               // payload.query,
               "}")

       return make_new_http_status(.OK, HttpStatusText[.OK]), response
   }


   //Route:  /api/v1/projects/{projectID}/collections/*
   if numberOfSegments == 6 && segments[4] == "collections" {
       collectionName := segments[5]

       newCollection := make_new_collection(collectionName, .STANDARD)
       // defer free(newCollection)

       // First create the collection file
       createSuccess := create_collection_file(projectContext, newCollection)
       if createSuccess != nil {
           users.log_user_server_event(currentUser, users.make_new_server_event(
           fmt.tprintf("Failed to create Collection: %s", collectionName),
           ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s", projectContext.projectName, collectionName), .POST,))
           return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: Failed to create collection %s\n", collectionName)
       }

       // Then encrypt the newly created collection
       masterKey, keyErr := security.get_user_master_key(projectContext.userID)
       if keyErr != nil {
           return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), "Failed to get encryption key\n"
       }
       defer security.clear_key_from_memory(masterKey)

       _, encryptionError := security.encrypt_collection(projectContext, newCollection, masterKey)
       if encryptionError != nil {
           return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: Failed to encrypt collection %s\n", collectionName)
       }

       users.log_user_server_event(currentUser, users.make_new_server_event(
       fmt.tprintf("Successfully created Collection: %s", collectionName),
       ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collection/%s", projectContext.projectName, collectionName), .POST,))
       return make_new_http_status(.CREATE, HttpStatusText[.CREATE]), tprintf("Request Successful: Created Collection '%s'\n", collectionName)
   }

   if numberOfSegments == 8 && segments[4] == "collections" && segments[6] == "clusters" {

       userID, authenticated := require_authentication(headers)
       if !authenticated {
           return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
       }

       collectionName := segments[5]
       clusterName := segments[7]

       return secure_collection_operation(projectContext, collectionName, clusterName,
           proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> (string, ^lib.Error) {
               currentUser:= users.make_new_user(projCTX.userID)
               fetchSuccess := data.create_cluster_block_in_collection(projCTX, collection, cluster)
               if fetchSuccess != nil {
                   users.log_user_server_event(currentUser, users.make_new_server_event(
                   fmt.tprintf("Failed to create Cluster: %s in Collection: %s",cluster.name, collection.name),
                   ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collection/%s/clusters/%s", projCTX.projectName, collection.name, cluster.name), .POST,))
                   return fmt.tprintf("Request Failed: Failed to created Cluster: '%s' in Collection: %s\n", cluster.name, collection.name), fetchSuccess
               }

               users.log_user_server_event(currentUser, users.make_new_server_event(
               fmt.tprintf("Successfully created Cluster: %s in Collection: %s",cluster.name, collection.name),
               ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collection/%s/clusters/%s", projCTX.projectName, collection.name, cluster.name), .POST,))
               return fmt.tprintf("Request Successful: Created Cluster: '%s' in Collection: %s\n", cluster.name, collection.name), no_error()
           })
   }

   if numberOfSegments == 10 && segments[4] == "collections" && segments[6] == "clusters" && segments[8] == "records" {

       userID, authenticated := require_authentication(headers)
       if !authenticated {
           return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
       }

       pathAndQuery := strings.split(path, "?")
       if len(pathAndQuery) != 2 {
           return  make_new_http_status(.FORBIDDEN, HttpStatusText[.FORBIDDEN]) ,"Request Failed: Missing 'value' or 'type' assigned in query parameters"
       }

       query := pathAndQuery[1]
       queryParamsMap := parse_query_string(query)
       // defer delete(queryParamsMap)

       collectionName:= segments[5]
       clusterName:= segments[7]
       recordName:string
       recordNameSplit:= strings.split(segments[9], "?")
       recordName = recordNameSplit[0]

       return secure_collection_operation(projectContext, collectionName, clusterName, recordName, queryParamsMap,
           proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record, queryParams: map[string]string) -> (string, ^lib.Error) {
               currentUser:= users.make_new_user(projCTX.userID)
               typeToUpper := strings.to_upper(queryParams["type"])

               newRecordDataType: RecordDataTypes
               record.typeAsString = typeToUpper

               for  dataTypeStringValue, dataTypeToken in RecordDataTypesStrings {
                   if dataTypeStringValue == record.typeAsString {
                       newRecordDataType= dataTypeToken
                       break
                   }
               }
               record.type = newRecordDataType
               record.value = queryParams["value"]

               id, incrementError:= increment_record_id(projCTX, collection, cluster)
               if incrementError != nil{
                   return "", incrementError
               }
               record.id = id

               creationSuccess:= create_record_within_cluster(projCTX, collection, cluster, record)
               if creationSuccess != nil{
                   users.log_user_server_event(currentUser, users.make_new_server_event(
                   fmt.tprintf("Failed to create Record: %s Cluster: %s in Collection: %s", record.name, cluster.name, collection.name),
                   ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collection/%s/clusters/%s/record/%s?type=%s&value=%s", projCTX.projectName, collection.name, cluster.name, record.name, record.typeAsString, record.value), .POST,))
                   return fmt.tprintf("Request Failed. Failed to create Record: %s in Cluster: %s in Collection: %s\n", record.name, cluster.name, collection.name), creationSuccess
               }

               users.log_user_server_event(currentUser, users.make_new_server_event(
               fmt.tprintf("Successfully created Record: %s Cluster: %s in Collection: %s", record.name, cluster.name, collection.name),
               ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collection/%s/clusters/%s/record/%s?type=%s&value=%s", projCTX.projectName, collection.name, cluster.name, record.name, record.typeAsString, record.value), .POST,))
               return fmt.tprintf("Request Successful. Created Record: %s in Cluster: %s in Collection: %s\n", record.name, cluster.name, collection.name), no_error()
           })
   }

   free_all(context.allocator)
   return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]), "Not Found\n"
}

handle_delete_request:: proc(method: lib.HttpMethod, path: string, headers: map[string]string, args: []string) -> (^lib.HttpStatus, string){
    using lib
    using data
    using fmt

    if method != .DELETE {
        return make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST]), "Method not allowed\n"
    }

    segments := split_path_into_segments(path)

    //Route: /api/v1/user/{user_id}
    if len(segments) == 4 && segments[0] == "api" && segments[1] == "v1" && segments[2] == "user"{
        appConfig := config.get_config()
        userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)
        currentUser:= users.make_new_user(userID)

        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        if rateLimited {
            return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
        }


        if users.delete_user_account(currentUser) != nil{
            users.log_user_server_event(currentUser, users.make_new_server_event(
            "Failed to delete user",
            ServerEventType.ERROR, time.now(), true, "/api/v1/user/", .DELETE,))
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), "Could not delete users account"
        }else{
            users.log_user_server_event(currentUser, users.make_new_server_event(
            "Successfully deleted user",
            ServerEventType.SUCCESS, time.now(), true, "/api/v1/user/", .DELETE,))
            return make_new_http_status(.OK, HttpStatusText[.OK]), "Operation Successful: Safely deleted users account.\n"
        }
    }


    // Route: /api/v1/projects/{project_name}
    //Delete a project of the passed in name
    if len(segments) == 4 && segments[0] == "api" && segments[1] == "v1" && segments[2] == "projects"  {
        appConfig := config.get_config()
        userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)

        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        if rateLimited {
            return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
        }

        if len(segments[3]) != 0{
            args[0] = segments[3]
            return handle_delete_project(headers, args)
        }
        return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Missing project name \n"
    }

    appConfig := config.get_config()
    userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)

    if !authenticated {
        return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
    }

    if rateLimited {
        return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
    }

    // Extract project context for other operations
    projectContext, projectContextOK := extract_project_context(path, headers)
    if !projectContextOK {
        return make_new_http_status(.CONFLICT, HttpStatusText[.CONFLICT]), "Unauthorized or invalid project\n"
    }
    // defer free(projectContext)
    numberOfSegments := len(segments)

    // Route: /api/v1/projects/{project_name}/collections/{collection_name}
    // Delete the collection of the passed in name
    if numberOfSegments == 6 && segments[4] == "collections" {

        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]

        return secure_collection_operation(projectContext, collectionName,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection) -> (string, ^lib.Error) {
                currentUser:= users.make_new_user(projCTX.userID)
                createSuccess := erase_collection(projCTX, collection)
                if createSuccess != nil {
                    users.log_user_server_event(currentUser, users.make_new_server_event(
                    fmt.tprintf("Failed to delete Collection: %s in Project: %s", collection.name, projCTX.projectName),
                    ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s", projCTX.projectName, collection.name), .DELETE,))
                    newHTTPStatus := make_new_http_status(.OK, HttpStatusText[.OK])
                    return "", createSuccess
                }

                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Successfully deleted Collection: %s in Project: %s", collection.name, projCTX.projectName),
                ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s", projCTX.projectName, collection.name), .DELETE,))
                return fmt.tprintf("Request Successful: Deleted Collection: %s\n", collection.name), no_error()
            })
    }

    // Route: /api/v1/projects/{project_name}/collections/{collection_name}/clusters/{cluster_name}
    // Delete the cluster with the passed in name within the passed in collection
    if numberOfSegments == 8 && segments[4] == "collections" && segments[6] == "clusters" {

        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName := segments[5]
        clusterName := segments[7]

        return secure_collection_operation(projectContext, collectionName, clusterName,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> (string, ^lib.Error) {
                currentUser:= users.make_new_user(projCTX.userID)
                deleteSuccess := data.erase_cluster(projCTX, collection, cluster)
                if deleteSuccess != nil {
                    users.log_user_server_event(currentUser, users.make_new_server_event(
                    fmt.tprintf("Failed to delete Cluster: %s in Collection: %s in Project: %s", cluster.name,collection.name, projCTX.projectName),
                    ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s", projCTX.projectName, collection.name, cluster.name), .DELETE,))
                    return "", deleteSuccess
                }

                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Successfully deleted Cluster: %s in Collection: %s in Project: %s", cluster.name, collection.name, projCTX.projectName),
                ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s", projCTX.projectName, collection.name, cluster.name), .DELETE,))
                return fmt.tprintf("Request Successful: Deleted Cluster %s in Collection: %s\n", cluster.name, collection.name), no_error()
            })
    }


    // Route: /api/v1/projects/{project_name}/collections/{collection_name}/clusters/{cluster_name}/records/{record_name}
    // Delete the record with the passed in name in the passed cluster within the passed in collection
    if numberOfSegments == 10 && segments[4] == "collections" && segments[6] == "clusters" && segments[8] == "records" {

        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }

        collectionName:= segments[5]
        clusterName:= segments[7]
        recordName: = segments[9]

        return secure_collection_operation(projectContext, collectionName, clusterName, recordName,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> (string, ^lib.Error) {
                currentUser:= users.make_new_user(projCTX.userID)
                deleteSuccess:= data.erase_record(projCTX, collection, cluster, record)
                if deleteSuccess != nil{
                    users.log_user_server_event(currentUser, users.make_new_server_event(
                    fmt.tprintf("Successfully deleted Record: %s Cluster: %s in Collection: %s in Project: %s", record.name ,cluster.name, collection.name, projCTX.projectName),
                    ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s", projCTX.projectName, collection.name, cluster.name, record.name), .DELETE,))
                    return "", deleteSuccess
                }

                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Successfully deleted Record: %s Cluster: %s in Collection: %s in Project: %s", record.name ,cluster.name, collection.name, projCTX.projectName),
                ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s", projCTX.projectName, collection.name, cluster.name, record.name), .DELETE,))
                return fmt.tprintf("Request Successful: Delete Record: %s in Cluster: %s in Collection %s\n", record.name, cluster.name, collection.name), no_error()
            })
    }

    //IF ROUTE IS'NT FOUND
    return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]), "Not Found\n"
}

//Handle Updating data structures
handle_put_request :: proc(method: lib.HttpMethod, path: string, headers: map[string]string, args: []string) -> (^lib.HttpStatus, string){
    using lib
    using data
    using config

    if method != .PUT do return make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST]), "Method Not Allowed\n"

    appConfig := get_config()
    userID, authenticated, rateLimited := require_authentication_with_rate_limit(headers, appConfig.security.rateLimitRequestsPerMinute)
    currentUser:= users.make_new_user(userID)

    if !authenticated {
        return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
    }

    if rateLimited {
        return make_new_http_status(.TOO_MANY_REQUESTS, HttpStatusText[.TOO_MANY_REQUESTS]), "Rate limit exceeded - too many requests\n"
    }

    // Extract project context
    projectContext, projectContextOK := extract_project_context(path, headers)
    if !projectContextOK {
        return make_new_http_status(.CONFLICT, HttpStatusText[.CONFLICT]), "Request Failed: Unauthorized or invalid project\n"
    }
    // defer free(projectContext)

    segments := split_path_into_segments(path)
    numberOfSegments := len(segments)

    // Route: /api/v1/projects/{oldname}?rename={newname}
    if numberOfSegments == 4 && segments[2] == "projects"{
        // Require authentication for project listing
        userID, authenticated := require_authentication(headers)
        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }
        projectContext, err := extract_project_context(path, headers)
        // defer free(projectContext)

        // Split the query params from the reat of path and make sure the len of params is valid
        pathAndQuery := strings.split(path, "?")
        if len(pathAndQuery) != 2 {
            return  make_new_http_status(.FORBIDDEN, HttpStatusText[.FORBIDDEN]) ,"Request Failed: Missing 'value' or 'type' assigned in query parameters"
        }

        query := pathAndQuery[1]
        queryParamsMap := parse_query_string(query)
        // defer delete(queryParamsMap)

        //Split the project name from the query params
        projectOldName:= strings.split(segments[3], "?")


        projectNewName:=queryParamsMap["rename"]
        newProjPath:= fmt.tprintf("%s%s/projects/%s", currentOstrichPathConfig.projectBasePath, projectContext.userID,projectNewName)

        renameError:= projects.rename_project(projectContext, newProjPath)
        if renameError == nil {
            //Remove the old project.JSON file
            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Successfully updated Project name: %s to %s ",projectContext.projectName, projectOldName[0]),
            ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/?rename=%s",projectOldName[0], projectNewName ), .PUT,))

            oldJSONFile:= fmt.tprintf("%s/project.json", newProjPath)
            removeError:=os.remove(oldJSONFile)
            if removeError != nil{
                return  make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: There was a internal server side error in OstrichDB\n Could remove project.json file" )
            }

            //Make a temp new proj ctx
            newProjContext:= new(ProjectContext)
            newProjContext.basePath = newProjPath //Set the new path for the new project context

            // defer free(newProjContext)

            //Generate project metadata to store
            metadata := lib.ProjectMetadata {
            projectID = newProjContext.projectID,
            projectName = projectNewName,
            userID = projectContext.userID,
            createdAt = time.now(),
            version = "1.0",
            }

            //Make a new project.JSON file
            _, openError:= os.open(fmt.tprintf("%s/project.json",newProjPath), os.O_CREATE, FILE_MODE_RW_ALL)
            if openError != nil{
                 return  make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: There was a internal server side error in OstrichDB\n Could not create new project.json file" )
            }

            //Store the new project metadata
            saveMetadataSuccess := projects.save_project_metadata(newProjContext, &metadata)
            if !saveMetadataSuccess{
                return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: Failed to updated Project: %s's metadata", projectOldName, projectNewName )
            }
            return make_new_http_status(.OK, HttpStatusText[.OK]), fmt.tprintf("Request Successful: Renamed Project: %s to %s", projectOldName[0], projectNewName )
        }else{

            users.log_user_server_event(currentUser, users.make_new_server_event(
            fmt.tprintf("Failed to update Project name: %s to %s ",projectContext.projectName, projectOldName[0]),
            ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/?rename=%s",projectOldName[0], projectNewName ), .PUT,))
            return make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR]), fmt.tprintf("Request Failed: Failed to rename Project: %s to %s", projectOldName, projectNewName )
        }
    }

    // Route: /api/v1/projects/{projectName}/collections/}{oldCollectionName}?rename={newCollectionName}
     if numberOfSegments == 6 && segments[2] == "projects"  && segments[4] == "collections"{
        // Require authentication for project listing
        userID, authenticated := require_authentication(headers)

        if !authenticated {
            return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
        }
        projectContext, err := extract_project_context(path, headers)
        // defer free(projectContext)
        // Split the query params from the reat of path and make sure the len of params is valid
        pathAndQuery := strings.split(path, "?")
        if len(pathAndQuery) != 2 {
            return  make_new_http_status(.FORBIDDEN, HttpStatusText[.FORBIDDEN]) ,"Request Failed: Missing 'value' or 'type' assigned in query parameters"
        }
        query := pathAndQuery[1]
        queryParamsMap := parse_query_string(query)
        // defer delete(queryParamsMap)

        //Split the collection name from the query params
        oldCollectionName:= strings.split(segments[5], "?")
        // defer delete(oldCollectionName)

        return secure_collection_operation(projectContext, oldCollectionName[0], queryParamsMap,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, queryParams: map[string]string) -> (string, ^lib.Error) {
                currentUser:= users.make_new_user(projCTX.userID)
                newCollectionName:=queryParams["rename"]

                newCollection:= make_new_collection(newCollectionName, .STANDARD)
                newCollection.name = newCollectionName

                renameResult := data.rename_collection(projCTX, collection, newCollection)
                if renameResult != nil {
                    users.log_user_server_event(currentUser, users.make_new_server_event(
                    fmt.tprintf("Failed to update Collection name: %s to %s ",collection.name, newCollectionName),
                    ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/?rename=%s",projCTX.projectName, collection.name, newCollectionName ), .PUT,))
                    return fmt.tprintf("Request Failed: Failed to rename Collection: %s to %s", collection.name, newCollectionName), renameResult
                }

                users.log_user_server_event(currentUser, users.make_new_server_event(
                fmt.tprintf("Successfully update Collection name: %s to %s ",collection.name, newCollectionName),
                ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/?rename=%s",projCTX.projectName, collection.name, newCollectionName ), .PUT,))
                return fmt.tprintf("Request Successful: Successfully renamed Collection: %s to %s", collection.name, newCollectionName), no_error()
            })
     }

    // Route: /api/v1/projects/{projectName}/collections/}{collectionName}/clusters/{oldClusterName}?rename={newClusterName}
    if numberOfSegments == 8 && segments[2] == "projects"  && segments[4] == "collections" &&  segments[6] == "clusters"{
          // Require authentication for project listing
          userID, authenticated := require_authentication(headers)
          if !authenticated {
              return make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED]), "Unauthorized - valid JWT token required\n"
          }
          projectContext, err := extract_project_context(path, headers)
          // defer free(projectContext)
          // Split the query params from the reat of path and make sure the len of params is valid
          pathAndQuery := strings.split(path, "?")
          if len(pathAndQuery) != 2 {
              return  make_new_http_status(.FORBIDDEN, HttpStatusText[.FORBIDDEN]) ,"Request Failed: Missing 'value' or 'type' assigned in query parameters"
          }
          query := pathAndQuery[1]
          queryParamsMap := parse_query_string(query)
          // defer delete(queryParamsMap)

          //Split the collection name from the query params
          oldClusterName:= strings.split(segments[7], "?")
          // defer delete(oldClusterName)
          collectionName:= segments[5]

          return secure_collection_operation(projectContext, collectionName, oldClusterName[0], queryParamsMap,
              proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, queryParams: map[string]string) -> (string, ^lib.Error) {
                  currentUser:= users.make_new_user(projCTX.userID)
                  newClusterName:=queryParams["rename"]

                  renameSuccess:= data.rename_cluster(projCTX, collection, cluster, newClusterName)
                  if renameSuccess != nil {
                      users.log_user_server_event(currentUser, users.make_new_server_event(
                      fmt.tprintf("Failed to update Cluster name: %s to %s ",cluster.name, newClusterName),
                      ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/?rename=%s",projCTX.projectName, collection.name, collection.name, cluster.name, newClusterName), .PUT,))
                      return "", renameSuccess
                  }

                  users.log_user_server_event(currentUser, users.make_new_server_event(
                  fmt.tprintf("Successfully updated Cluster name: %s to %s ",cluster.name, newClusterName),
                  ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/?rename=%s",projCTX.projectName, collection.name, collection.name, cluster.name, newClusterName), .PUT,))
                  return fmt.tprintf("Request Successful: Renamed Cluster: %s to %s", cluster.name, newClusterName), no_error()
              })
    }

    //Unlike the other data structures where you only update the name, record names, types and values can all be updated
    // Route: /api/v1/projects/{projectName}/collections/}{collectionName}/clustsers/{clusterName}/records/{oldRecordName}{query}}
    if numberOfSegments == 10 && segments[2] == "projects"  && segments[4] == "collections" &&  segments[6] == "clusters" && segments[8] == "records"{

        //First parse the query params to see what being updated
        pathAndQuery := strings.split(path, "?")
        if len(pathAndQuery) != 2 {
            return  make_new_http_status(.FORBIDDEN, HttpStatusText[.FORBIDDEN]) ,"Request Failed: Missing 'value' or 'type' assigned in query parameters"
        }

        query := pathAndQuery[1]
        queryParamsMap := parse_query_string(query)
        // defer delete(queryParamsMap)

        collectionName:= segments[5]
        clusterName := segments[7]
        recordName:= strings.split(segments[9], "?")
        // defer delete(recordName)

        return secure_collection_operation(projectContext, collectionName, clusterName, recordName[0], queryParamsMap,
            proc(projCTX: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record, queryParams: map[string]string) -> (string, ^lib.Error) {

                currentUser:= users.make_new_user(projCTX.userID)
                //Go over the params to determine which operation to perform
                for paramKey, paramValue in queryParams {
                    switch paramKey {
                    case "rename":
                        //Handle updating the Records name
                        renameSuccess:= data.rename_record(projCTX, collection, cluster, record, paramValue)
                        if renameSuccess != nil {
                            users.log_user_server_event(currentUser, users.make_new_server_event(
                            fmt.tprintf("Failed to update Record name: %s to %s ",record.name, paramValue),
                            ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s/?rename=%s",projCTX.projectName, collection.name, collection.name, cluster.name, record.name, paramValue), .PUT,))
                            return "", renameSuccess
                        }

                        users.log_user_server_event(currentUser, users.make_new_server_event(
                        fmt.tprintf("Successfully updated Record name: %s to %s ",record.name, paramValue),
                        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s/?rename=%s",projCTX.projectName, collection.name, collection.name, cluster.name, record.name, paramValue), .PUT,))
                        return fmt.tprintf("Request Successful: Successfully renamed Record: %s to %s", record.name, paramValue), no_error()

                    case "type":
                        //Handle updating the Records type
                        typeUpdateSuccess:= data.update_record_data_type(projCTX, collection, cluster, record, paramValue)
                        if typeUpdateSuccess != nil {
                            users.log_user_server_event(currentUser, users.make_new_server_event(
                            fmt.tprintf("Failed to update Record: %s's type: %s to %s ",record.name, record.typeAsString, paramValue),
                            ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s/?type=%s",projCTX.projectName, collection.name, collection.name, cluster.name, record.name, paramValue), .PUT,))
                            return "", typeUpdateSuccess
                        }

                        users.log_user_server_event(currentUser, users.make_new_server_event(
                        fmt.tprintf("Successfully update Record: %s's type: %s to %s ",record.name, record.typeAsString, paramValue),
                        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s/?type=%s",projCTX.projectName, collection.name, collection.name, cluster.name, record.name, paramValue), .PUT,))
                        return fmt.tprintf("Request Successful: Successfully updated Record: %s's type to %s", record.name, paramValue), no_error()

                    case "value":
                        //Handle updating the records value
                        valueUpdateSuccess:= data.update_record_value(projCTX, collection, cluster, record, paramValue)
                        if valueUpdateSuccess != nil {
                            users.log_user_server_event(currentUser, users.make_new_server_event(
                            fmt.tprintf("Failed to update Record: %s's value: %s to %s ",record.name, record.value, paramValue),
                            ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s/?value=%s",projCTX.projectName, collection.name, collection.name, cluster.name, record.name, paramValue), .PUT,))
                            return "", valueUpdateSuccess
                        }

                        users.log_user_server_event(currentUser, users.make_new_server_event(
                        fmt.tprintf("Successfully updated Record: %s's value: %s to %s ",record.name, record.value, paramValue),
                        ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s/collections/%s/clusters/%s/records/%s/?value=%s",projCTX.projectName, collection.name, collection.name, cluster.name, record.name, paramValue), .PUT,))
                        return fmt.tprintf("Request Successful: Successfully updated Record: %s's value", record.name), no_error()
                    }
                }
                return "No valid operation specified", make_new_err(.UNKNOWN_ERROR, get_caller_location())
            })
    }
    return make_new_http_status(.NOT_FOUND, HttpStatusText[.NOT_FOUND]), "Not Found\n"
}

// Health check handler. Route: {base_path}/health
// //Could be modified in the future to check health of particular collections or something like that??
handle_health_check :: proc(method: lib.HttpMethod, path: string, headers: map[string]string, args: []string = {""}) -> (^lib.HttpStatus, string) {
    using lib
    using fmt

    if method != .GET {
        newHTTPStatus := make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST])
        return newHTTPStatus, "Request Failed: Method not allowed\n"
    }

    version, _:=  get_ost_version()
    uptime := newServerSession.total_runtime
    healthData:= fmt.tprintf(`
        %s
        "status": "healthy",
        "version": "%s",
        "api_version": "v1",
        "timestamp": "%v",
        "uptime_seconds": %v
        %s`,
        "{", string(version), time.now(), uptime, "}")
    response := healthData
    return make_new_http_status(.OK, HttpStatusText[.OK]), response
}

handle_create_project :: proc(headers: map[string]string, args: []string) -> (^lib.HttpStatus, string) {
    using lib
    using config
    using fmt

    if len(args) < 1 {
        newHTTPStatus := make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST])
        return newHTTPStatus, "Project name required\n"
    }

    userID, authenticated := require_authentication(headers)
    currentUser:= users.make_new_user(userID)
    if !authenticated || userID == "" {
        newHTTPStatus := make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED])
        return newHTTPStatus, "Authentication required\n"
    }

    projectName := args[0]

    projectContext := projects.make_new_project_context(userID, projectName)
    if projectContext == nil {
        newHTTPStatus := make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST])
        return newHTTPStatus, "Invalid project context\n"
    }
    // defer free(projectContext)

    // Initialize project structure (this will create user directory if needed)
    if !projects.init_project_structure(projectContext) {
        users.log_user_server_event(currentUser, users.make_new_server_event(
        "Failed to create project",
        ServerEventType.ERROR, time.now(), true, "/api/v1/projects", .POST,))
        newHTTPStatus := make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR])
        return newHTTPStatus, "Failed to create project\n"
    }

    response := tprintf(`%s"project_id": "%s", "project_name": "%s", "user_id": "%s", "status": "created"%s`, "{",
        projectContext.projectID, projectName, userID, "}")

    newHTTPStatus := make_new_http_status(.CREATE, HttpStatusText[.CREATE])
    users.log_user_server_event(currentUser, users.make_new_server_event(
    fmt.tprintf("Successfully created Project: %s", projectContext.projectName),
    ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s", projectContext.projectName), .POST,))
    return newHTTPStatus, response
}

handle_delete_project :: proc(headers: map[string]string, args: []string = {""}) -> (^lib.HttpStatus, string) {
    using lib
    using config
    using fmt

    if len(args) < 1 {
        newHTTPStatus := make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST])
        return newHTTPStatus, "Project name required\n"
    }

    userID, authenticated := require_authentication(headers)
    currentUser:= users.make_new_user(userID)
    if !authenticated || userID == "" {
        newHTTPStatus := make_new_http_status(.UNAUTHORIZED, HttpStatusText[.UNAUTHORIZED])
        return newHTTPStatus, "Authentication required\n"
    }

    projectName := args[0]

    projectContext := projects.make_new_project_context(userID, projectName)
    if projectContext == nil {
        newHTTPStatus := make_new_http_status(.BAD_REQUEST, HttpStatusText[.BAD_REQUEST])
        return newHTTPStatus, "Invalid project context\n"
    }
    // defer free(projectContext)

    // Verify user owns this project before deletion
    if !projects.verify_project_access(projectContext, userID) {
        newHTTPStatus := make_new_http_status(.FORBIDDEN, HttpStatusText[.FORBIDDEN])
        return newHTTPStatus, "Access denied to project\n"
    }

    eraseProjectSuccess := projects.erase_project(projectContext)
    if !eraseProjectSuccess {
        users.log_user_server_event(currentUser, users.make_new_server_event(
        fmt.tprintf("Failed to delete Project: %s", projectContext.projectName),
        ServerEventType.ERROR, time.now(), true, fmt.tprintf("/api/v1/projects/%s", projectContext.projectName), .DELETE,))
        newHTTPStatus := make_new_http_status(.SERVER_ERROR, HttpStatusText[.SERVER_ERROR])
        return newHTTPStatus, "Failed to delete project\n"
    }

    users.log_user_server_event(currentUser, users.make_new_server_event(
    fmt.tprintf("Successfully delete Project: %s", projectContext.projectName),
    ServerEventType.SUCCESS, time.now(), true, fmt.tprintf("/api/v1/projects/%s", projectContext.projectName), .DELETE,))
    newHTTPStatus := make_new_http_status(.OK, HttpStatusText[.OK])
    return newHTTPStatus, "Successfully deleted project\n"
}


//QUERY PARAM HELPER PROCS BELOW

//Helper used to parse a query parameter string into a map.
// Note: The query parameter string must already be split off from the path. Find an example of this in the above handle_post_request() proc
parse_query_string :: proc(query: string) -> map[string]string {
    using strings

	params := make(map[string]string)
	pairs := split(query, "&")
	for pair in pairs {
		keyValue := split(pair, "=")
		if len(keyValue) == 2 {
			params[keyValue[0]] = keyValue[1]
		}
	}
	return params
}

//Helper proc to verify a path has a valid query param
@(require_results)
has_valid_query_parameters :: proc(path: string) -> bool {
    using strings

    if !contains(path, "?") {
        return false
    }

    queryString := extract_query_from_path(path)
    trimmedQuery := trim_space(queryString)

    // Check if there's actual content after the "?"
    if len(trimmedQuery) == 0 {
        return false
    }

    // Check if there are actual key=value pairs
    pairs := split(trimmedQuery, "&")
    // defer delete(pairs)

    for pair in pairs {
        if contains(pair, "=") && len(trim_space(pair)) > 1 {
            return true
        }
    }

    return false
}

// Parse query parameters into structured format
@(require_results)
parse_query_params :: proc(query: string) -> lib.QueryParams {
    using lib
    using strings

    params := QueryParams{
        recordType = "",
        recordID = -1,
        limit = -1,
        offset = 0,
        search = "",
        value = "",
        valueContains = "",
        sortBy = "name",
        sortOrder = "asc",
        minValue = "",
        maxValue = "",
        dateFrom = "",
        dateTo = "",
    }

    if query == "" do return params

    pairs := split(query, "&")
    // defer delete(pairs)

    for pair in pairs {
        keyValue := split(pair, "=")
        // defer delete(keyValue)

        if len(keyValue) == 2 {
            key := trim_space(keyValue[0])
            value := trim_space(keyValue[1])

            switch key {
            case "type":
                params.recordType = to_upper(value)
            case "id":
                if id, ok := strconv.parse_i64(value); ok {
                    params.recordID = id
                }
            case "limit":
                if limit, ok := strconv.parse_int(value); ok {
                    params.limit = limit
                }
            case "offset":
                if offset, ok := strconv.parse_int(value); ok {
                    params.offset = offset
                }
            case "search":
                params.search = value
            case "value":
                params.value = value
            case "valueContains":
                params.valueContains = value
            case "sortBy":
                params.sortBy = to_lower(value)
            case "sortOrder":
                params.sortOrder = to_lower(value)
            case "minValue":
                params.minValue = value
            case "maxValue":
                params.maxValue = value
            case "dateFrom":
                params.dateFrom = value
            case "dateTo":
                params.dateTo = value
            }
        }
    }

    return params
}

// Convert query params to search criteria
@(require_results)
query_params_to_search_criteria :: proc(params: lib.QueryParams) -> lib.SearchCriteria {
    using lib
    using strings

    criteria := SearchCriteria{}

    // Set search patterns - prioritize specific search fields
    if len(params.search) > 0 {
        criteria.namePattern = params.search
    }

    // This was likely causing the issue when only valueContains was used
    if len(params.value) > 0 {
        criteria.valuePattern = params.value
    } else if len(params.valueContains) > 0 {
        // Make sure we set the valuePattern for valueContains
        criteria.valuePattern = params.valueContains
    }

    criteria.typeFilter = .INVALID // Default to no filter
    if len(params.recordType) > 0 {
        typeFound := false
        for typeString, typeEnum in RecordDataTypesStrings {
            if typeString == params.recordType {
                criteria.typeFilter = typeEnum
                typeFound = true
                break
            }
        }
        // If type not found, keep it as INVALID (no type filtering)
    }

    // Set value range
    criteria.valueRange.min = params.minValue
    criteria.valueRange.max = params.maxValue
    criteria.valueRange.hasMin = len(params.minValue) > 0
    criteria.valueRange.hasMax = len(params.maxValue) > 0

    // Set sort parameters
    switch params.sortBy {
    case "name":
        criteria.sortField = .NAME
    case "value":
        criteria.sortField = .VALUE
    case "type":
        criteria.sortField = .TYPE
    case "id":
        criteria.sortField = .ID
    case:
        criteria.sortField = .NAME // Default
    }

    criteria.sortOrder = .ASC if params.sortOrder == "asc" else .DESC

    return criteria
}

// Helper to extract query string from path
@(require_results)
extract_query_from_path :: proc(path: string) -> string {
    using strings

    if queryStart := index(path, "?"); queryStart != -1 {
        return path[queryStart + 1:]
    }
    return ""
}

//Helper to split a path by the '/' character
@(require_results)
split_path_into_segments :: proc(path: string) -> []string {
    using strings

    // First, remove query parameters from the path
    cleanPath := path
    if queryPos := index(path, "?"); queryPos != -1 {
        cleanPath = path[:queryPos]
    }

    // Then split normally
    return split(trim_prefix(cleanPath, "/"), "/")
}


//Shoutout to ClaudeAI by Anthropic for this shit
@(require_results)
clean_metadata_field :: proc(input: string, defaultValue: string) -> string {
    using strings

    if len(input) == 0 {
        return clone(defaultValue)
    }

    trimmed := trim_space(input)
    if len(trimmed) == 0 {
        return clone(defaultValue)
    }

    // Remove any non-printable characters and escape quotes
    cleaned := make([dynamic]u8)
    // defer delete(cleaned)

    for char in transmute([]u8)trimmed {
        // Only include printable ASCII characters
        if char >= 32 && char <= 126 {
            if char == '"' {
                // Escape quotes
                append(&cleaned, '\\')
                append(&cleaned, '"')
            } else {
                append(&cleaned, char)
            }
        } else if char == ' ' {
            // Keep spaces
            append(&cleaned, char)
        }
        // Skip all other characters (control characters, etc.)
    }

    cleanedStr := string(cleaned[:])
    if len(trim_space(cleanedStr)) == 0 {
        return clone(defaultValue)
    }

    return clone(cleanedStr)
}


ManualQueryPayload :: struct {
    query : ^lib.Query,
    path: string, //aka endpoint :)
    method: lib.HttpMethod,
    methodStr: string
}

make_manual_query_payload :: proc(query: ^lib.Query, path: string) -> ^ManualQueryPayload{
    using lib

    payload:= new(ManualQueryPayload)
    payload.query = query
    payload.path = path

    #partial switch(query.commandToken){
        case .NEW:
            payload.method = .POST
            payload.methodStr = HttpMethodString[.POST]
            break
        case .RENAME, .CHANGE_TYPE, .SET:
            payload.method = .PUT
            payload.methodStr = HttpMethodString[.PUT]
            break
        case .ERASE:
            payload.method = .DELETE
            payload.methodStr = HttpMethodString[.DELETE]
            break
        case .FETCH:
            payload.method = .GET
            payload.methodStr = HttpMethodString[.GET]
            break
    }

    return payload
}