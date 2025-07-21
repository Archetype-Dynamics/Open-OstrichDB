package  data

import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:math/rand"
import "../../config"
import lib "../../../library"
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
            clusters within the OstrichDB engine.
*********************************************************/

//Dont worry about why I have these
TAB_NEW_R_BRACE := "\t\n},"
R_BRACE_COMMA   := "\n},\n"
NEWLINE         := "\n"

//Allocates memory for a new lib.Cluster, then returns a pointer to it. Remember to free() in calling procedure
@(require_results)
make_new_cluster :: proc(collection: ^lib.Collection, clusterName: string) -> ^lib.Cluster {
	using lib

    cluster := new(Cluster)
    cluster.parent = collection^
	cluster.name = clusterName //Todo: add a check for the length of and special chars in the name
	cluster.id = 0 //numbers will be auto-incremented per collections
	cluster.numberOfRecords = 0
	cluster.records= make([dynamic]Record, 0)
    // cluster.size = 0 //Might not use the size member during creation???
	return cluster
}

//writes the physical cluster block to the passed in collection
//Assigns the clusters name and id with the passed in cluster.name and cluster.id
@(require_results)
create_cluster_block_in_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> ^lib.Error{
    using lib

    buf:= new([32]byte)
    defer free(buf)


    collectionPath := get_specific_collection_full_path(projectContext, collection) //Check to ensure the collection the user wants to create the cluster in exists
    defer delete(collectionPath)

    collectionExists, checkError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || checkError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    //Now check to see if there is already a cluster that exists with the name
    clusterAlreadyExists, _:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if clusterAlreadyExists {
        return  make_new_err(.CLUSTER_ALREADY_EXISTS, get_caller_location())
    }


    clusterNameLine:[]string= {"\n{\n\tcluster_name :identifier: %n"}
    clusterIDLine:[]string= {"\n\tcluster_id :identifier: %i\n\t\n},\n\n"}


    file, openSuccess := os.open(collectionPath, os.O_APPEND | os.O_WRONLY, 0o666)
    if openSuccess != 0 {
        return make_new_err(.COLLECTION_CANNOT_OPEN, get_caller_location())
    }

    //Find the cluster name placeholder and write the new the clusterName in its place
    for i:= 0; i < len(clusterNameLine); i+= 1{
        if strings.contains(clusterNameLine[i], "%n"){
            newClusterName, replaceSuccess := strings.replace(clusterNameLine[i], "%n", cluster.name, -1)
            defer delete(newClusterName)
            if !replaceSuccess{
                return make_new_err(.CLUSTER_CANNOT_UPDATE, get_caller_location())
            }

            _ , writeSuccess:= os.write(file, transmute([]u8)newClusterName)
            if writeSuccess != 0{
                return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
            }
        }
    }
    //get the current count of clusters in the collection.
    clusterIDCount, clusterCountErrors:=  get_cluster_count_within_collection(projectContext, collection)
    if clusterCountErrors != nil{
        return make_new_err(.CLUSTER_CANNOT_UPDATE, get_caller_location())
    }

    //Set the new ID to the next number
    cluster.id = clusterIDCount
    //Find the cluster ID placeholder and write the new the clusterID in its place
    for i:= 0; i < len(clusterIDLine); i += 1{
        if strings.contains(clusterIDLine[i], "%i"){
            newClusterID, replaceSuccess:= strings.replace(clusterIDLine[i], "%i", strconv.append_int(buf[:], cluster.id, 10), -1)
            defer delete(newClusterID)
            if !replaceSuccess{
                return make_new_err(.CLUSTER_CANNOT_UPDATE, get_caller_location())
            }

            _ , writeSuccess:= os.write(file, transmute([]u8)newClusterID)
            if writeSuccess != 0{
                return make_new_err(.CLUSTER_CANNOT_WRITE, get_caller_location())
            }
        }
    }

    os.close(file)
    return update_metadata_fields_after_operation(projectContext, collection)
}

//Renames a cluster to the passed in newName arg. The old name is passed in via ^cluster.name
@(require_results)
rename_cluster :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection,  cluster: ^lib.Cluster, newName: string) ->^lib.Error{
    using lib
    using fmt

    // Check if a cluster with the new name already exists
    newCluster:= make_new_cluster(collection, newName)
    defer free(newCluster)

    clusterExistsInCollection, _ := check_if_cluster_exsists_in_collection(projectContext,collection, newCluster)
    if clusterExistsInCollection {
        return make_new_err(.CLUSTER_ALREADY_EXISTS, get_caller_location())
    }

    // Use the standardized parser to get the entire collection
    parsedCollection, parseError := parse_entire_collection(projectContext, collection)
    defer free(&parsedCollection)

    if parseError != nil {
        return parseError
    }

    // Check if the target cluster exists in the parsed data
    targetClusterFound := false
    for parsedCluster in parsedCollection.body.clusters {
        if parsedCluster.name == cluster.name {
            targetClusterFound = true
            break
        }
    }

    if !targetClusterFound {
        return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    // Create new body content with renamed cluster
    newBodyContent := make([dynamic]u8)
    defer delete(newBodyContent)

    for parsedCluster in parsedCollection.body.clusters {
        if parsedCluster.name == cluster.name {
            // Rename this cluster by replacing the name in raw content
            renamedContent, replaceError := strings.replace(parsedCluster.rawContent,
                fmt.tprintf("cluster_name :identifier: %s", cluster.name),
                fmt.tprintf("cluster_name :identifier: %s", newName), 1)

            if !replaceError {
                return make_new_err(.CLUSTER_CANNOT_UPDATE, get_caller_location())
            }

            append(&newBodyContent, ..transmute([]u8)NEWLINE)
            append(&newBodyContent, ..transmute([]u8)renamedContent)
            append(&newBodyContent, ..transmute([]u8)R_BRACE_COMMA)
        } else {
            // Keep other clusters unchanged
            append(&newBodyContent, ..transmute([]u8)NEWLINE)
            append(&newBodyContent, ..transmute([]u8)parsedCluster.rawContent)
            append(&newBodyContent, ..transmute([]u8)R_BRACE_COMMA)
        }
    }

    // Reconstruct the collection with metadata header and new body
    newCollectionContent := reconstruct_collection(
        parsedCollection.metadataHeader,
        string(newBodyContent[:])
    )
    defer delete(newCollectionContent)

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    writeSuccess := write_to_file(collectionPath, transmute([]byte)newCollectionContent, get_caller_location())
    if !writeSuccess {
        return make_new_err(.CLUSTER_CANNOT_WRITE, get_caller_location())
    }

    return update_metadata_fields_after_operation(projectContext, collection)
}
//Finds and deletes the cluster with the passed in cluster.name
@(require_results)
erase_cluster :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> ^lib.Error {
    using lib

    parsedCollection, parseError := parse_entire_collection(projectContext, collection)
    defer free(&parsedCollection)

    if parseError != nil {
        return parseError
    }

    targetClusterFound := false
    for parsedCluster in parsedCollection.body.clusters {
        if parsedCluster.name == cluster.name {
            targetClusterFound = true
            break
        }
    }

    if !targetClusterFound {
        return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    // Create a new array of clusters excluding the one to be deleted
    newClusters := make([dynamic]ParsedCluster)
    defer delete(newClusters)

    for parsedCluster in parsedCollection.body.clusters {
        if parsedCluster.name != cluster.name {
            clusterCopy := ParsedCluster{
                name = strings.clone(parsedCluster.name),
                id = parsedCluster.id,
                records = parsedCluster.records,
                rawContent = strings.clone(parsedCluster.rawContent),
                startIndex = parsedCluster.startIndex,
                endIndex = parsedCluster.endIndex,
                lineNumber = parsedCluster.lineNumber,
                recordCount = parsedCluster.recordCount,
                isEmpty = parsedCluster.isEmpty,
            }
            append(&newClusters, clusterCopy)
        }
    }

    newBodyContent := make([dynamic]u8)
    defer delete(newBodyContent)

    for cluster, i in newClusters {
        append(&newBodyContent, ..transmute([]u8)cluster.rawContent)
        // Add closing brace and comma (except for last cluster)
        append(&newBodyContent, ..transmute([]u8)R_BRACE_COMMA)
        if i < len(newClusters) - 1 {
            append(&newBodyContent, '\n')
        }
    }

    // Reconstruct the the Collection with metadata header and the  new body
    newCollectionContent := reconstruct_collection(
        parsedCollection.metadataHeader,
        string(newBodyContent[:])
    )
    defer delete(newCollectionContent)

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    writeSuccess := write_to_file(collectionPath, transmute([]byte)newCollectionContent, get_caller_location())
    if !writeSuccess {
        return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
    }

    return update_metadata_fields_after_operation(projectContext, collection)
}

//Finds and returns the passed in cluster and all its data as a whole, excluding the identifier typed records
//Dont forget to delete the return value in the calling prcoedure
@(require_results)
fetch_cluster ::proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster)-> (string, ^lib.Error){
    using lib
    using fmt
    using config

    parsedCluster, parseError := parse_specific_cluster(projectContext, collection, cluster.name)
    defer free(&parsedCluster)

    if parseError != nil {
        return "", parseError
    }

    return strings.clone(parsedCluster.rawContent), no_error()
}


//Deletes all data within a cluster excluding the name, id all while retaining the clusters structure
@(require_results, deprecated="This legacy procedure has been deprectated")
purge_cluster ::proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster) -> ^lib.Error{
    using lib
    using fmt

    // Use the standardized parser to get the entire collection
    parsedCollection, parseError := parse_entire_collection(projectContext, collection)
    defer free(&parsedCollection)

    if parseError != nil {
        return parseError
    }

    // Create new body content with purged cluster
    newBodyContent := make([dynamic]u8)
    defer delete(newBodyContent)

    for parsedCluster in parsedCollection.body.clusters {
        if parsedCluster.name == cluster.name {
            // Purge this cluster - keep only name and id
            append(&newBodyContent, '{')
            append(&newBodyContent, '\n')
            append(&newBodyContent, ..transmute([]u8)fmt.tprintf("\tcluster_name :identifier: %s\n", parsedCluster.name))
            append(&newBodyContent, ..transmute([]u8)fmt.tprintf("\tcluster_id :identifier: %d\n", parsedCluster.id))
            append(&newBodyContent, ..transmute([]u8)TAB_NEW_R_BRACE)
        } else {
            // Keep other clusters unchanged
            append(&newBodyContent, ..transmute([]u8)parsedCluster.rawContent)
            append(&newBodyContent, ..transmute([]u8)R_BRACE_COMMA)
        }
    }

    // Reconstruct the collection with metadata header and new body
    newCollectionContent := reconstruct_collection(
        parsedCollection.metadataHeader,
        string(newBodyContent[:])
    )
    defer delete(newCollectionContent)

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    writeSuccess := write_to_file(collectionPath, transmute([]byte)newCollectionContent, get_caller_location())
    if !writeSuccess {
        return  make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
    }

    return update_metadata_fields_after_operation(projectContext, collection)
}
//Parses the passed in Collection gets every Clusters names and tries to find a match to the passed in cluster.name
@(require_results)
check_if_cluster_exsists_in_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> (bool, ^lib.Error) {
    using lib

    clusterNames, getError := get_all_cluster_names_in_collection(projectContext, collection)
    defer delete(clusterNames)

    if getError != nil {
        return false, getError
    }

    // Check if our target cluster exists
    for clusterName in clusterNames {
        if strings.compare(clusterName, cluster.name) == 0 {
            return true, update_metadata_fields_after_operation(projectContext, collection)
        }
    }

    return false, no_error()
}

//This proc is used to get key information about all clusters within a collection e.g:
// Names of all clusters
// IDs of all clusters
// Size of all clusters
// Total Cluster Count
// Total record count in each cluster
get_all_clusters_info :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> ([dynamic]ParsedCluster, ^lib.Error) {
    using lib

    parsedCollection, parserError:=parse_collection_body_only(projectContext, collection)
    return parsedCollection.body.clusters, no_error()
}

//Returns 2 dynamic arrays:
//1. ALL cluster ids in a collectionas i64
//2. ALL cluster ids in a collection as strings
//remember to delete the returned values in the calling procedure
@(require_results)
get_all_cluster_ids_in_collection :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection) -> ([dynamic]i64, [dynamic]string,  ^lib.Error){
    using lib
    using fmt

	IDs := make([dynamic]i64)
	idsStringArray := make([dynamic]string)

	collectionExists, colCheckError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || colCheckError != nil{
        return  IDs, idsStringArray, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    // Use the standardized parser to get clusters only
    parsedClusters, parseError := parse_collection_clusters_only(projectContext, collection)
    defer delete(parsedClusters)

    if parseError != nil {
        return IDs, idsStringArray, parseError
    }

    // Extract IDs from parsed clusters
    for cluster in parsedClusters {
        append(&IDs, cluster.id)
        idStr := fmt.tprintf("%d", cluster.id)
        append(&idsStringArray, idStr)
    }

	return IDs, idsStringArray, no_error()
}

//Returns a dynamic array of all cluster names within the passed in collection
//Remember to delete return value in calling procedure
@(require_results)
get_all_cluster_names_in_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> ([dynamic]string, ^lib.Error) {
    using lib

    clusterNames := make([dynamic]string)

    // Use the standardized parser to get clusters only
    parsedClusters, parseError := parse_collection_clusters_only(projectContext, collection)
    defer delete(parsedClusters)

    if parseError != nil {
        return clusterNames, parseError
    }

    // Extract names from parsed clusters
    for cluster in parsedClusters {
        append(&clusterNames, strings.clone(cluster.name))
    }

    return clusterNames, no_error()
}

// Reads over the passed in collection for the passed in cluster, then returns the id of that cluster
@(require_results)
get_clusters_id_by_name :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> (clusterID: i64, error: ^lib.Error) {
    using lib

    // Use the parser to get the specific cluster
    parsedCluster, parseError := parse_specific_cluster(projectContext, collection, cluster.name)
    defer free(&parsedCluster)

    if parseError != nil {
        return -1, parseError
    }

    return parsedCluster.id, no_error()
}

//Reads over the passed in collection for the passed in cluster ID. If found return the name of the cluster
@(require_results)
get_clusters_name_by_id ::proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, clusterID:i64) -> (clusterName:string, error:^lib.Error){
    using lib
    using fmt

    clusterName = ""

    collectionExists, colCheckError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || colCheckError != nil{
        return  clusterName, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    // Use the standardized parser to get clusters only
    parsedClusters, parseError := parse_collection_clusters_only(projectContext, collection)
    defer delete(parsedClusters)

    if parseError != nil {
        return clusterName, parseError
    }

    // Find cluster with matching ID
    for cluster in parsedClusters {
        if cluster.id == clusterID {
            return strings.clone(cluster.name), no_error()
        }
    }

    return  clusterName, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
}

//Returns the size of the passed in cluster in bytes, this EXCLUDES the following:
//1. The opening curly brace
//2. The closing curly brace and it trailing comma
//3. The cluster name
//4. The cluster id
//5. Tab characters
//6. Newline characters
//7. Whitespace characters
@(cold, require_results)
get_cluster_size ::proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster) -> (int, ^lib.Error){
    using lib
    using fmt

    size := 0

    collectionExists, colCheckError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || colCheckError != nil{
        return  -1,  make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, clusterCheck:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || clusterCheck != nil{
        return  -2, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    // Use the parser to get the specific cluster
    parsedCluster, parseError := parse_specific_cluster(projectContext, collection, cluster.name)
    defer free(&parsedCluster)

    if parseError != nil {
        return -3, parseError
    }

    // Calculate size by parsing the raw content and excluding metadata
    lines := strings.split(parsedCluster.rawContent, "\n")

    for line in lines {
        trimmed := strings.trim_space(line)
        // Skip cluster name, id lines, empty lines, and braces
        if strings.contains(trimmed, "cluster_name :identifier:") ||
           strings.contains(trimmed, "cluster_id :identifier:") ||
           trimmed == "" || trimmed == "{" {
            continue
        }

        // Count only the actual content, removing whitespace and special characters
        size += len(strings.trim_space(line))
    }

    return  size, no_error()
}

//Returns the number of Clusters within a Collection
get_cluster_count_within_collection ::proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (i64, ^lib.Error) {
    using lib
    using fmt

    clusterCount :i64= 0

    // Use the standardized parser to get clusters only
    parsedClusters, parseError := parse_collection_clusters_only(projectContext, collection)
    defer delete(parsedClusters)

    if parseError != nil {
        return clusterCount, parseError
    }

    for cluster in parsedClusters {
        clusterCount +=1
    }

    return clusterCount, no_error()
}