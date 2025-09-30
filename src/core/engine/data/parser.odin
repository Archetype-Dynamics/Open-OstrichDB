package data

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:strconv"
import "../../config"
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
            Standardized collection and subdata structure
            parser for consistent data extraction across all OstrichDB operations.
*********************************************************/

// Core parsed data structures
ParsedCollection :: struct {
    name:string,
    metadataHeader: CollectionMetadata,
    body: CollectionBody,
    rawCollection: string,
    filePath: string,
    fileSize: int,
    parseTime: time.Time,
}

// Collection body structure
CollectionBody :: struct {
    clusters: [dynamic]ParsedCluster,
    rawBody: string,
    clusterCount: int,
    recordCount: int,
    isEmpty: bool,
}

// Collection separation structure for clean metadata/body division
CollectionSeparation :: struct {
    metadataHeader: string,
    body: string,
    metadataStartIndex: int,
    metadataEndIndex: int,
    bodyStartIndex: int,
    hasMetadata: bool,
    hasBody: bool,
}

CollectionMetadata :: struct {
    encryptionState: string,
    fileFormatVersion: string,
    permission: string,
    dateCreation: string,
    dateModified: string,
    fileSize: string,
    checksum: string,
    rawContent: string,
    isValid: bool,
    headerStartIndex: int,
    headerEndIndex: int,
}

ParsedCluster :: struct {
    name: string,
    id: i64,
    records: [dynamic]ParsedRecord,
    rawContent: string,
    startIndex: int,
    endIndex: int,
    lineNumber: int,
    recordCount: int,
    isEmpty: bool,
}

ParsedRecord :: struct {
    name: string,
    type: lib.RecordDataTypes,
    typeAsString: string,
    value: string,
    rawRecord: string,
    lineNumber: int,
    characterPosition: int,
    isValid: bool,
}

ParseOptions :: struct {
    parseMetadata: bool,
    parseClusters: bool,
    parseRecords: bool,
    validateData: bool,
    preserveFormatting: bool,
    targetCluster: string,  // Parse only this cluster if specified
}

ParserError :: struct {
    message: string,
    lineNumber: int,
    characterPosition: int,
    ctx: string,
    severity: ParserErrorSeverity,
}

ParserErrorSeverity :: enum {
    INFO = 0,
    WARNING,
    ERROR,
    CRITICAL,
}

//Option to parse the ENTIRE Collection
FULL_COLLECTION_PARSE :: ParseOptions{
    parseMetadata = true,
    parseClusters = true,
    parseRecords = true,
    validateData = true,
    preserveFormatting = true,
}

//Option to parse ONLY the Collection's METADATA HEADER
METADATA_HEADER_ONLY_PARSE :: ParseOptions{
    parseMetadata = true,
    parseClusters = false,
    parseRecords = false,
    validateData = true,
    preserveFormatting = false,
}

//Option to parse ONLY the BODY of a Collection...This includes Clusters and Records
COLLECTION_BODY_ONLY_PARSE:: ParseOptions{
    parseMetadata = false,
    parseClusters = true,
    parseRecords = true,
    validateData = true,
    preserveFormatting = true,
}

//Option to parse ONLY the CLUSTERS. This DOES NOT include their subsequent Records
CLUSTERS_ONLY_PARSE :: ParseOptions{
    parseMetadata = false,
    parseClusters = true,
    parseRecords = false,
    validateData = true,
    preserveFormatting = false,
}

//Option to parse ONLY RECORDS. This means clusters need to be parsed to technically, might rework
RECORDS_ONLY_PARSE :: ParseOptions{
    parseMetadata = false,
    parseClusters = true,
    parseRecords = true,
    validateData = true,
    preserveFormatting = false,
}

// COLLECTION SEPARATION FUNCTIONS - NEW CORE FUNCTIONALITY

// Separates a collection into metadata header and body sections
@(require_results)
separate_collection :: proc(collection: string, ) -> (CollectionSeparation, ^lib.Error) {
    using lib
    using strings

    separation := CollectionSeparation{}

    // Find metadata boundaries
    metadataStart := index(collection, METADATA_START)
    metadataEnd := index(collection, METADATA_END)

    if metadataStart == -1 {
        // No metadata found - entire collection is body
        separation.body = clone(collection, context.allocator)
        separation.bodyStartIndex = 0
        separation.hasMetadata = false
        separation.hasBody = len(collection) > 0
        return separation, no_error()
    }

    if metadataEnd == -1 {
        // Malformed metadata (start but no end)
        return separation, make_new_err(.METADATA_HEADER_NOT_FOUND, get_caller_location())
    }

    // Calculate indices
    separation.metadataStartIndex = metadataStart
    separation.metadataEndIndex = metadataEnd + len(METADATA_END)
    separation.bodyStartIndex = separation.metadataEndIndex

    // Extract metadata header (including markers)
    metadataHeaderClone:= clone(collection[metadataStart:separation.metadataEndIndex])
    separation.metadataHeader = metadataHeaderClone
    separation.hasMetadata = true

    // Extract body (everything after metadata)
    if separation.bodyStartIndex < len(collection) {
        bodyData := collection[separation.bodyStartIndex:]
        bodyDataClone:= clone(bodyData)
        separation.body = bodyDataClone
        separation.hasBody = len(separation.body) > 0
    } else {
        separation.body = ""
        separation.hasBody = false
    }

    return separation, no_error()
}

// Parses collection from file and returns separated data
@(require_results)
separate_collection_from_file :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (CollectionSeparation, ^lib.Error) {
    using lib

    // Verify collection exists
    collectionExists, checkError := check_if_collection_exists(projectContext, collection)
    if !collectionExists || checkError != nil {
        return CollectionSeparation{}, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    // Read file data
    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    data, readSuccess := read_file(collectionPath, get_caller_location())
    if !readSuccess {
        return CollectionSeparation{}, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    // Separate collection
    return separate_collection(string(data))
}

// Extracts ONLY the metadata header from a collection
@(require_results)
extract_metadata_header_only :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (string, ^lib.Error) {
    using lib
    using strings

    separation, separationError := separate_collection_from_file(projectContext, collection)
    // defer free(&separation)

    if separationError != nil {
        return "", separationError
    }

    if !separation.hasMetadata {
        return "", make_new_err(.METADATA_HEADER_NOT_FOUND, get_caller_location())
    }

    return clone(separation.metadataHeader), no_error()
}

// Extracts ONLY the body from a collection (no metadata)
@(require_results)
extract_body_only :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (string, ^lib.Error) {
    using lib
    using strings

    separation, separationError := separate_collection_from_file(projectContext, collection)

    if separationError != nil {
        return "", separationError
    }

    if !separation.hasBody {
        return "", no_error() // Empty body is not an error
    }

    return clone(separation.body), no_error()
}

// Extracts metadata header from raw collection string
@(require_results)
extract_metadata_header_from_collection :: proc(collection: string) -> (string, ^lib.Error) {
    using lib
    using strings

    separation, separationError := separate_collection(collection)

    if separationError != nil {
        return "", separationError
    }

    if !separation.hasMetadata {
        return "", make_new_err(.METADATA_HEADER_NOT_FOUND, get_caller_location())
    }

    return clone(separation.metadataHeader), no_error()
}

// Extracts body from raw collection string
@(require_results)
extract_body_from_collection :: proc(collection: string) -> (string, ^lib.Error) {
    using lib
    using strings


    separation, separationError := separate_collection(collection)

    if separationError != nil {
        return "", separationError
    }

    return clone(separation.body), no_error()
}

// COLLECTION BODY CONSTRUCTION FUNCTIONS

// Creates a CollectionBody from raw body string and clusters
@(require_results)
make_collection_body :: proc(rawBody: string, clusters: [dynamic]ParsedCluster) -> CollectionBody {
    using lib
    using strings

    body := CollectionBody{}
    rawBodyClone:=clone(rawBody)
    // defer delete(rawBodyClone)
    body.rawBody = rawBodyClone
    body.clusters = clusters
    body.clusterCount = len(clusters)
    body.isEmpty = len(clusters) == 0

    // Calculate total record count across all clusters
    totalRecords := 0
    for cluster in clusters {
        totalRecords += cluster.recordCount
    }
    body.recordCount = totalRecords

    return body
}

// Creates an empty CollectionBody
@(require_results)
make_empty_collection_body :: proc() -> CollectionBody {
    return CollectionBody{
        clusters = make([dynamic]ParsedCluster),
        rawBody = "",
        clusterCount = 0,
        recordCount = 0,
        isEmpty = true,
    }
}


// Main collection parser with options
@(require_results)
parse_collection_with_options :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, options: ParseOptions) -> (ParsedCollection, ^lib.Error) {
    using lib
    using fmt
    using strings

    parsed := ParsedCollection{}
    parsed.parseTime = time.now()

    // Get file path and verify collection exists
    collectionPath := get_specific_collection_full_path(projectContext, collection)
    // defer delete(collectionPath)
    parsed.filePath = collectionPath

    collectionExists, checkError := check_if_collection_exists(projectContext, collection)
    if !collectionExists || checkError != nil {
        return parsed, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    // Read file data
    data, readSuccess := read_file(collectionPath, get_caller_location())
    // defer delete(data)
    if !readSuccess {
        return parsed, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }
    dataClone:=clone(string(data))
    // defer delete(dataClone)
    parsed.rawCollection = dataClone
    parsed.fileSize = len(data)

    // Separate collection into metadata and body
    separation, separationError := separate_collection(dataClone)

    if separationError != nil {
        return parsed, separationError
    }

    // Parse metadata if requested
    if options.parseMetadata && separation.hasMetadata {
        metadata, metadataError := parse_metadata_header(separation.metadataHeader)
        if metadataError != nil {
            return parsed, metadataError
        }
        parsed.metadataHeader = metadata
    }

    // Parse body if requested
    if separation.hasBody {
        if options.parseClusters {
            clusters, clustersError := parse_clusters_section(separation.body, options)
            if clustersError != nil {
                return parsed, clustersError
            }
            parsed.body = make_collection_body(separation.body, clusters)
        } else {
            // Just store raw body without parsing clusters
            parsed.body = make_collection_body(separation.body, make([dynamic]ParsedCluster))
        }
    } else {
        // Empty body
        parsed.body = make_empty_collection_body()
    }

    return parsed, no_error()
}

//Parses and returns an entire collection
@(require_results)
parse_entire_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (ParsedCollection, ^lib.Error) {
    return parse_collection_with_options(projectContext, collection, FULL_COLLECTION_PARSE)
}

// Parses ONLY the body (clusters and records) - NO METADATA
@(require_results)
parse_collection_body_only ::proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (ParsedCollection, ^lib.Error) {
    parsed, parseError := parse_collection_with_options(projectContext, collection, COLLECTION_BODY_ONLY_PARSE)

    // Ensure we truly have no metadata in the result for body-only parsing
    if parseError == nil {
        parsed.metadataHeader = CollectionMetadata{} // Reset to empty
    }

    return parsed, parseError
}

// Parse only metadata
@(require_results)
parse_metadata_header_only :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (CollectionMetadata, ^lib.Error) {
    parsed, err := parse_collection_with_options(projectContext, collection, METADATA_HEADER_ONLY_PARSE)
    return parsed.metadataHeader, err
}

// Parse only clusters (no records)
@(require_results)
parse_collection_clusters_only :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> ([dynamic]ParsedCluster, ^lib.Error) {
    parsed, err := parse_collection_with_options(projectContext, collection, CLUSTERS_ONLY_PARSE)
    return parsed.body.clusters, err
}


// Parse specific cluster by name
@(require_results)
parse_specific_cluster :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, clusterName: string) -> (ParsedCluster, ^lib.Error) {
    using lib
    options := RECORDS_ONLY_PARSE
    options.targetCluster = clusterName

    parsed, err := parse_collection_with_options(projectContext, collection, options)
    // defer free(&parsed)

    if err != nil {
        return ParsedCluster{}, err
    }

    // Find the specific cluster
    for cluster in parsed.body.clusters {
        if cluster.name == clusterName {
            return cluster, no_error()
        }
    }

    return ParsedCluster{}, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
}

// METADATA PARSING

@(require_results)
parse_metadata_header :: proc(metadataHeader: string) -> (CollectionMetadata, ^lib.Error) {
    using lib
    using strings

    metadata := CollectionMetadata{}


    // Find metadata boundaries
    metadataStart := index(metadataHeader, METADATA_START)
    metadataEnd := index(metadataHeader, METADATA_END)

    if metadataStart == -1 || metadataEnd == -1 {
        return metadata, make_new_err(.METADATA_HEADER_NOT_FOUND, get_caller_location())
    }

    metadata.headerStartIndex = metadataStart
    metadata.headerEndIndex = metadataEnd + len(METADATA_END)

    // Extract metadata data
    metadataData := metadataHeader[metadataStart:metadata.headerEndIndex]
    rawContentClone:= clone(metadataData)
    // defer delete(rawContentClone)
    metadata.rawContent = rawContentClone

    // Parse metadata lines
    lines := split(metadataData, "\n")
    defer delete(lines)

    for line in lines {
        line := trim_space(line)
        if len(line) == 0 || !has_prefix(line, "#") {
            continue
        }

        if contains(line, "Encryption State:") {
            metadata.encryptionState = extract_metadata_value(line)
        } else if contains(line, "File Format Version:") {
            metadata.fileFormatVersion = extract_metadata_value(line)
        } else if contains(line, "Date of Creation:") {
            metadata.dateCreation = extract_metadata_value(line)
        } else if contains(line, "Date Last Modified:") {
            metadata.dateModified = extract_metadata_value(line)
        } else if contains(line, "File Size:") {
            metadata.fileSize = extract_metadata_value(line)
        } else if contains(line, "Checksum:") {
            metadata.checksum = extract_metadata_value(line)
        }
    }


    metadata.isValid = validate_metadata(&metadata)
    return metadata, no_error()
}


@(require_results)
extract_metadata_value :: proc(line: string) -> string {
    using strings

    // Look for the first (and only) colon in metadata lines
    if colonIndex := index(line, ":"); colonIndex != -1 {
        // Extract everything after the colon and trim whitespace
        value := line[colonIndex + 1:]
        trimmedValue := trim_space(value)

        // If the value is empty, return a default value
        if len(trimmedValue) == 0 {
            return "Unknown"
        }

        return clone(trimmedValue)
    }
    return "Unknown"
}

validate_metadata :: proc(metadata: ^CollectionMetadata) -> bool {
    return len(metadata.encryptionState) > 0 &&
           len(metadata.fileFormatVersion) > 0
}

// CLUSTER PARSING

@(require_results)
parse_clusters_section :: proc(bodyData: string, options: ParseOptions) -> ([dynamic]ParsedCluster, ^lib.Error) {
    using lib
    using strings

    clusters := make([dynamic]ParsedCluster)

    if len(bodyData) == 0 {
        return clusters, no_error() // Empty body is valid
    }

    // Split by cluster boundaries
    clusterBlocks := split(bodyData, "},")
    defer delete(clusterBlocks)

    lineNumber := 1 // Start counting from 1 since this is just body

    for clusterBlock , blockIndex in clusterBlocks {
        clusterBlock := trim_space(clusterBlock)

        if len(clusterBlock) == 0 {
            continue
        }

        // Parse cluster
        cluster, clusterError := parse_single_cluster(clusterBlock, lineNumber, 0, options)
        if clusterError != nil {
            continue // Skip malformed clusters
        }

        // If target cluster specified, only include that one
        if len(options.targetCluster) > 0 {
            if cluster.name == options.targetCluster {
                append(&clusters, cluster)
                break
            }
        } else {
                append(&clusters, cluster) //TODO: This line causes a mem leak but not sure how to fix - Marshall
        }
        lineNumber += count_lines_in_string(clusterBlock)
    }

    return clusters, no_error()
}

@(require_results)
parse_single_cluster :: proc(clusterBlock: string, startLine: int, clusterOffset: int, options: ParseOptions) -> (ParsedCluster, ^lib.Error) {
    using lib
    using strings

    cluster := ParsedCluster{}
    cluster.lineNumber = startLine
    cluster.startIndex = clusterOffset
    cluster.endIndex = clusterOffset + len(clusterBlock)
    rawContentClone:= clone(clusterBlock)
    // defer delete(rawContentClone)
    cluster.rawContent =rawContentClone

    lines := split(clusterBlock, "\n")
    defer delete(lines)

    currentLineNumber := startLine

    for line in lines {
        line := trim_space(line)

        if len(line) == 0 {
            currentLineNumber += 1
            continue
        }

        // Parse cluster name
        if contains(line, "cluster_name :identifier:") {
            extractedClusterName:= extract_identifier_value(line, "cluster_name")
            // defer delete(extractedClusterName)
            cluster.name = extractedClusterName
        }
        else if contains(line, "cluster_id :identifier:") {
        // Parse cluster ID
            idStr := extract_identifier_value(line, "cluster_id")
            if id, ok := strconv.parse_i64(idStr); ok {
                cluster.id = id
                // delete(idStr)
            }
        }
        else if options.parseRecords && contains(line, ":") &&
        // Parse records if requested
                !contains(line, "cluster_name") &&
                !contains(line, "cluster_id") &&
                !contains(line, "#") {
            record, recordError := parse_single_record(strings.clone(line), currentLineNumber)
            if recordError == nil {
                {//To prevent memory leaks here I added this context allocator scope - Marshall
                    context.allocator = context.temp_allocator

                    append(&cluster.records, record)
                    cluster.recordCount += 1
                }
            }
        }

        currentLineNumber += 1
    }

    cluster.isEmpty = cluster.recordCount == 0
    return cluster, no_error()
}

@(require_results)
extract_identifier_value :: proc(line: string, identifier: string) -> string {
    using strings

    identLine := strings.concatenate([]string{identifier, " :identifier:"})
    // defer delete(identLine)
    if startIndex := index(line, identLine); startIndex != -1 {
        valueStart := startIndex + len(identLine)
        value := trim_space(line[valueStart:])
        return clone(value)
    }
    return ""
}
// RECORD PARSING

@(require_results)
parse_single_record :: proc(line: string, lineNumber: int) -> (ParsedRecord, ^lib.Error) {
    using lib
    using strings

    record := ParsedRecord{}
    rawRecordClone:= clone(line)

    record.rawRecord = rawRecordClone
    record.lineNumber = lineNumber

    // Parse format: name :type: value
    parts := split(line, ":")
    defer delete(parts)

    if len(parts) < 2 {
        return record, make_new_err(.RECORD_CANNOT_PARSE, get_caller_location())
    }

    // Extract name
    recordNameClone:= clone(trim_space(parts[0]))
    // defer delete(recordNameClone)
    record.name = recordNameClone

    // Extract type
    if len(parts) >= 2 {
        typeAsStringClone:= clone(trim_space(parts[1]))
        // defer delete(typeAsStringClone)
        record.typeAsString = typeAsStringClone

        // Convert string type to enum
        for typeString, typeEnum in RecordDataTypesStrings {
            if typeString == record.typeAsString {
                record.type = typeEnum
                break
            }
        }
    }

    // Extract value (everything after second colon)
    if len(parts) >= 3 {
        valueSlice := parts[2:]
        record.value = clone(trim_space(join(valueSlice, ":")))
    }

    record.isValid = validate_record(&record)
    return record, no_error()
}

validate_record :: proc(record: ^ParsedRecord) -> bool {
    return len(record.name) > 0 &&
           len(record.typeAsString) > 0 &&
           record.type != .INVALID
}

// QUERY AND SEARCH FUNCTIONS

// Find clusters by name pattern
@(require_results)
find_clusters_by_name :: proc(parsed: ^ParsedCollection, pattern: string) -> [dynamic]^ParsedCluster {
    using strings

    results := make([dynamic]^ParsedCluster)

    for &cluster in parsed.body.clusters {
        if contains(to_lower(cluster.name), to_lower(pattern)) {
            append(&results, &cluster)
        }
    }

    return results
}

// Get cluster by exact name
@(require_results)
get_cluster_by_name :: proc(parsed: ^ParsedCollection, name: string) -> ^ParsedCluster {
    for &cluster in parsed.body.clusters {
        if cluster.name == name {
            return &cluster
        }
    }
    return nil
}

// Get record by exact name within a cluster
@(require_results)
get_record_by_name :: proc(cluster: ^ParsedCluster, name: string) -> ^ParsedRecord {
    for &record in cluster.records {
        if record.name == name {
            return &record
        }
    }
    return nil
}

// Find records by search criteria
@(require_results)
find_records_by_criteria :: proc(cluster: ^ParsedCluster, criteria: lib.SearchCriteria) -> [dynamic]^ParsedRecord {
    using lib
    using strings

    results := make([dynamic]^ParsedRecord)

    for &record in cluster.records {
        matches := true

        // Name pattern matching
        if len(criteria.namePattern) > 0 {
            recordNameLower := to_lower(record.name)
            patternLower := to_lower(criteria.namePattern)
            if !contains(recordNameLower, patternLower) {
                matches = false
            }
        }

        // Value pattern matching
        if matches && len(criteria.valuePattern) > 0 {
            recordValueLower := to_lower(record.value)
            patternLower := to_lower(criteria.valuePattern)
            if !contains(recordValueLower, patternLower) {
                matches = false
            }
        }

        // Type filtering
        if matches && criteria.typeFilter != .INVALID {
            if record.type != criteria.typeFilter {
                matches = false
            }
        }

        if matches {
            append(&results, &record)
        }
    }

    return results
}

// Get all cluster names
@(require_results)
get_all_cluster_names :: proc(parsed: ^ParsedCollection) -> [dynamic]string {
    using strings

    names := make([dynamic]string)

    for cluster in parsed.body.clusters {
        append(&names, clone(cluster.name))
    }

    return names
}

// Get all record names in a cluster
@(require_results)
get_all_record_names :: proc(cluster: ^ParsedCluster) -> [dynamic]string {
    using strings

    names := make([dynamic]string)

    for record in cluster.records {
        append(&names, clone(record.name))
    }

    return names
}

// UTILITY FUNCTIONS

count_lines_in_metadata :: proc(collection: string) -> int {
    using lib
    using strings

    metadataEnd := index(collection, METADATA_END)
    if metadataEnd == -1 {
        return 0
    }

    metadataData := collection[:metadataEnd]
    return count(metadataData, "\n")
}

count_lines_in_string :: proc(data: string) -> int {
    using strings
    return count(data, "\n")
}


