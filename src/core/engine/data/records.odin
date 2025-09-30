package data

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"
import "../../config"
import lib "../../../library"
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
            This file contains all the logic for interacting with
            records within the OstrichDB engine.
*********************************************************/


//Allocates memory for a new lib.Record, then returns a pointer to it. Remember to free() in calling procedure
@(require_results)
make_new_record :: proc(collection: ^lib.Collection, cluster: ^lib.Cluster, recordName:string) -> ^lib.Record{
    using lib
    using fmt

    record:= new(Record)
    record.grandparent = collection^
    record.parent = cluster^
    record.id = 0
    record.name= recordName
    record.type = .INVALID
    record.typeAsString = ""
    record.value = ""

    return record
}

make_new_dynamic_record_array ::proc() ->^[dynamic]lib.Record{
    recordsArray:= new([dynamic]lib.Record)

    return recordsArray
}

//Appends the physcal recode line to the passed in cluster within the passed in collection
@(require_results)
create_record_within_cluster :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> ^lib.Error{
    using lib
    using fmt
    using strings

    isValidName, validityCheckError:= valid_record_name(record)
    if validityCheckError != nil || isValidName == false {
        users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = "Invalid record name provided",
            type = .CREATE_OPERATION,
            timestamp = lib.get_current_time()
        })
        return validityCheckError
    }

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)
    //Check to ensure the collection the user wants to create the cluster in exists
    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return  make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    //Now check to see if there is already a cluster that exists with the name
    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext,collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return  make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    //Now check to see if a record with the desired name already exists
    recordAlreadyExists, _:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if recordAlreadyExists{
        users.log_error_event(users.make_new_user(projectContext.userID), &lib.ErrorEvent{
            severity = .ERROR,
            description = fmt.tprintf("Record: %s already exists in Cluster: %s", record.name, cluster.name),
            type = .CREATE_OPERATION,
            timestamp = lib.get_current_time()
        })
        return make_new_err(.RECORD_ALREADY_EXISTS, get_caller_location())
    }


    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess {
        return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

	lines := split(string(data), "\n")
	defer delete(lines)

	clusterStart := -1
	closingBrace := -1

	// Find the cluster and its closing brace
	for i := 0; i < len(lines); i += 1 {
		if contains(lines[i], cluster.name) {
			clusterStart = i
		}
		if clusterStart != -1 && contains(lines[i], "}") {
			closingBrace = i
			break
		}
	}

	//check if a record with the desired name already exists within the specified cluster
	recordExists, _ := check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
	if recordExists {
		return make_new_err(.RECORD_ALREADY_EXISTS, get_caller_location())
	}

	//if the cluster is not found or the structure is invalid, return
	if clusterStart == -1 || closingBrace == -1 {
		return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
	}


	// construct the new record line
	newRecordLine := tprintf("\t%s :%s: %s", record.name, record.typeAsString, record.value)
	// Insert the new line and adjust the closing brace
	oldContent := make([dynamic]string, len(lines) + 1)
	defer delete(oldContent)

	copy(oldContent[:closingBrace], lines[:closingBrace])
	oldContent[closingBrace] = newRecordLine
	oldContent[closingBrace + 1] = "},"
	if closingBrace + 1 < len(lines) {
		copy(oldContent[closingBrace + 2:], lines[closingBrace + 1:])
	}
	newContent := join(oldContent[:], "\n")
	// defer delete(newContent)

	writeSuccess := write_to_file(collectionPath, transmute([]byte)newContent, get_caller_location())
	if !writeSuccess {
		 return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

    return update_metadata_fields_after_operation(projectContext, collection)
}

//Reads over the passed in collection and the passed in cluster for the record. renames the record.name with the newName arg
@(require_results)
rename_record :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, oldRecord: ^lib.Record, newName:string) -> ^lib.Error {
    using lib
    using fmt
    using strings


    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, oldRecord)
    if !recordExists || recCheckError != nil{
        return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

	newRecord:= make_new_record(collection, cluster, newName)
	defer free(newRecord)

    isValidName, validityCheckError:= valid_record_name(newRecord)
    if validityCheckError != nil || isValidName == false {
        return validityCheckError
    }

	//If there is already a record with the desired new name throw error
	recordExistsInCluster, rCheckErr:=check_if_record_exists_in_cluster(projectContext, collection,cluster,newRecord)
	if recordExistsInCluster || rCheckErr != nil{
        return make_new_err(.RECORD_ALREADY_EXISTS, get_caller_location())
	}

	collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)

	if !readSuccess {
	    return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	clusterBlocks := split(string(data), "},")
	defer delete(clusterBlocks)

	newContent := make([dynamic]u8)
	defer delete(newContent)

	recordFound := false

		for c in clusterBlocks {
			c := trim_space(c)
			if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
				// Found the correct cluster, now look for the record to rename
				lines := split(c, "\n")
				newCluster := make([dynamic]u8)
				defer delete(newCluster)

			for line in lines {
				trimmedLine := trim_space(line)
				if has_prefix(trimmedLine, tprintf("%s :", oldRecord.name)) {
					// Found the record to rename
					recordFound = true
					newLine, _:= replace(trimmedLine,tprintf("%s :", oldRecord.name),tprintf("%s :", newRecord.name),1,)
					append(&newCluster, "\t")
					append(&newCluster, ..transmute([]u8)newLine)
					append(&newCluster, "\n")
				} else if len(trimmedLine) > 0 {
					// Keep other lines unchanged
					append(&newCluster, ..transmute([]u8)line)
					append(&newCluster, "\n")
				}
			}

			// Add the modified cluster to the new content
			append(&newContent, ..newCluster[:])
			append(&newContent, "}")
			append(&newContent, ",\n\n")
		} else if len(c) > 0 {
			// Keep other clusters unchanged
			append(&newContent, ..transmute([]u8)c)
			append(&newContent, "\n}")
			append(&newContent, ",\n\n")
		}
	}

	if !recordFound {
		return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
	}

	// write new content to file
	writeSuccess := os.write_entire_file(collectionPath, newContent[:])
	if !writeSuccess{
        return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return update_metadata_fields_after_operation(projectContext, collection)
}
//finds a the passed in record, and physically updates its data type. keeps its value which will eventually need to be changed
@(require_results)
update_record_data_type :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record, newType: string) -> ^lib.Error {
    using lib
    using fmt
    using strings


    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)
	if !readSuccess {
		return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	lines := split(string(data), "\n")
	defer delete(lines)

	newLines := make([dynamic]string)
	defer delete(newLines)

	inTargetCluster := false
	recordUpdated := false

	// Find the cluster and update the record
	for line in lines {
		trimmedLine := trim_space(line)

		if trimmedLine == "{" {
			inTargetCluster = false
		}

		if contains(trimmedLine, tprintf("cluster_name :identifier: %s", cluster.name)) {
			inTargetCluster = true
		}

		if inTargetCluster && contains(trimmedLine, tprintf("%s :", record.name)) {
			// Keep the original indentation
			leadingWhitespace := split(line, record.name)[0]
			// Create new line with updated type
			newLine := tprintf("%s%s :%s: %s", leadingWhitespace, record.name, newType, record.value)
			append(&newLines, newLine)
			recordUpdated = true
		} else {
			append(&newLines, line)
		}

		if inTargetCluster && trimmedLine == "}," {
			inTargetCluster = false
		}
	}

	if !recordUpdated {
		return make_new_err(.RECORD_CANNOT_UPDATE, get_caller_location())
	}

	// Write the updated content back to file
	newContent := join(newLines[:], "\n")
	writeSuccess := write_to_file(collectionPath, transmute([]byte)newContent, get_caller_location())
	if !writeSuccess{
	    return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return update_metadata_fields_after_operation(projectContext, collection)
}

//Used to replace a records current value with the passed in newValue
@(require_results)
update_record_value :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record, newValue:any) -> ^lib.Error{
    using lib
    using fmt
    using strings


    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError !=nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess {
        return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    lines:= split(string(data), "\n")
    defer delete(lines)

    inTargetCluster := false
	recordUpdated := false

	//First look and find the record in the cluster
	for line, i in lines {
		trimmedLine := trim_space(line)

		if trimmedLine == "{" {
			inTargetCluster = false
		}

		if contains(trimmedLine, "cluster_name :identifier:") {
			clusterNameParts := split(trimmedLine, ":")
			if len(clusterNameParts) >= 3 {
				currentClusterName := trim_space(clusterNameParts[2])
				if to_upper(currentClusterName) == to_upper(cluster.name) {
					inTargetCluster = true
				}
			}
		}


		// if in the target cluster, find the record and update it
		targetRecordField := fmt.tprintf("%s :", record.name)
		if inTargetCluster && strings.has_prefix(trimmedLine, targetRecordField) {
			leadingWhitespace := split(line, record.name)[0]
			parts := split(trimmedLine, ":")
			if len(parts) >= 2 {
				lines[i] = tprintf(
					"\t%s:%s: %v",
					parts[0],
					parts[1],
					newValue,
				)
				recordUpdated = true
				break
			}
		}

		if inTargetCluster && trimmedLine == "}," {
			break
		}
	}

	if !recordUpdated {
		return make_new_err(.RECORD_CANNOT_UPDATE, get_caller_location())
	}

	newContent := join(lines, "\n")
	writeSuccess := write_to_file(collectionPath, transmute([]byte)newContent, get_caller_location())
	if !writeSuccess {
        return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return update_metadata_fields_after_operation(projectContext, collection)
}

//deletes the passed in records value while retaining its name and data type
@(require_results, deprecated="This legacy procedure has been deprectated")
purge_record :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record)-> ^lib.Error{
    using lib
    using fmt
    using strings

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)
	if !readSuccess {
		return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	lines := split(string(data), "\n")
	defer delete(lines)

	newLines := make([dynamic]string)
	defer delete(newLines)

	inTargetCluster := false
	recordPurged := false

	for line in lines {
		trimmedLine := trim_space(line)

		if trimmedLine == "{" {
			inTargetCluster = false
		}

		if contains(trimmedLine, tprintf("cluster_name :identifier: %s", cluster.name)) {
			inTargetCluster = true
		}

		if inTargetCluster && contains(trimmedLine, tprintf("%s :", record.name)) {
			parts := split(trimmedLine, ":")
			if len(parts) >= 3 {
				// Keep the record name and type, but remove the value
				// Maintain the original indentation and spacing
				leadingWhitespace := split(line, record.name)[0]
				newLine := tprintf(
					"%s%s :%s:",
					leadingWhitespace,
					trim_space(parts[0]),
					trim_space(parts[1]),
				)
				append(&newLines, newLine)
				recordPurged = true
			} else {
				append(&newLines, line)
			}
		} else {
			append(&newLines, line)
		}

		if inTargetCluster && trimmedLine == "}," {
			inTargetCluster = false
		}
	}

	if !recordPurged {
		return make_new_err(.RECORD_CANNOT_PURGE, get_caller_location())
	}

	newContent := join(newLines[:], "\n")
	writeSuccess := write_to_file(collectionPath, transmute([]byte)newContent, get_caller_location())
	if !writeSuccess{
        return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return no_error()
}

//deletes a record from a cluster
@(require_results)
erase_record :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> ^lib.Error {
	using lib
	using fmt
	using strings


 collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError!= nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext,collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError!= nil{
        return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)
	if !readSuccess {
		return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	lines := split(string(data), "\n")
	defer delete(lines)

	newLines := make([dynamic]string)
	defer delete(newLines)

	inTargetCluster := false
	isLastRecord := false
	recordCount := 0

	// First pass - count records in target cluster
	for line in lines {
		trimmedLine := trim_space(line)
		if contains(trimmedLine, tprintf("cluster_name :identifier: %s", cluster.name)) {
			inTargetCluster = true
			continue
		}
		if inTargetCluster {
			if trimmedLine == "}," {
				inTargetCluster = false
				continue
			}
			if len(trimmedLine) > 0 &&
			   !has_prefix(trimmedLine, "cluster_name") &&
			   !has_prefix(trimmedLine, "cluster_id") {
				recordCount += 1
			}
		}
	}

	// Second pass - rebuild content
	inTargetCluster = false
	for line in lines {
		trimmedLine := trim_space(line)

		if contains(trimmedLine, tprintf("cluster_name :identifier: %s", cluster.name)) {
			inTargetCluster = true
			append(&newLines, line)
			continue
		}

		if inTargetCluster {
			if has_prefix(trimmedLine, tprintf("%s :", record.name)) {
				if recordCount == 1 {
					isLastRecord = true
				}
				continue
			}

			if trimmedLine == "}," {
				if !isLastRecord {
					append(&newLines, line)
				} else {
					append(&newLines, "}")
				}
				inTargetCluster = false
				continue
			}
		}

		if !inTargetCluster || !has_prefix(trimmedLine, tprintf("%s :", record.name)) {
			append(&newLines, line)
		}
	}

	newContent := join(newLines[:], "\n")
	writeSuccess := write_to_file(collectionPath, transmute([]byte)newContent, get_caller_location())
	if !writeSuccess{
		return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return update_metadata_fields_after_operation(projectContext, collection)
}

//Reads over the passed in collection and cluster looking for the passed in record,
//assigns the records name, type, and value to a new lib.Record and returns it
@(require_results)
fetch_record :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> (lib.Record, ^lib.Error){
    using lib
    using fmt
    using strings


    collectionExists, colCheckExists:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckExists != nil{
        return Record{}, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheclError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheclError != nil{
        return Record{}, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil {
        return Record{}, make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    collectionPath:= lib.get_specific_collection_full_path(projectContext,collection)
    defer delete(collectionPath)

    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess{
        return Record{}, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    clusterBlocks:= split(string(data), "}")
    clusterContent, recordContent:string

    for c in clusterBlocks{
        if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)){
            startIndex := index(c, "{")
			if startIndex != -1 {
				// Extract the content between braces
				clusterContent = c[startIndex + 1:]
				// Trim any leading or trailing whitespace
				clusterContent = trim_space(clusterContent)
            }
        }
    }

   	for line in split_lines(clusterContent) {
        trimmedLine := trim_space(line)

        // Skip empty lines and identifier records
        if len(trimmedLine) == 0 ||
           has_prefix(trimmedLine, "cluster_name :identifier:") ||
           has_prefix(trimmedLine, "cluster_id :identifier:") {
            continue
        }

        // Check if line starts with the exact record name followed by space and colon
        if has_prefix(trimmedLine, tprintf("%s :", record.name)) {
            rec, parseError:= parse_record(trimmedLine)
            if parseError  != nil {
                return rec, parseError
            }else do return rec, no_error()
        }
	}

	return Record{}, make_new_err(.RECORD_CANNOT_GET,get_caller_location())
}

//Returns a dynamic array of strings containing all record names within a cluster
@(require_results)
get_all_record_names_in_cluster :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> ([dynamic]string, ^lib.Error) {
    using lib
    using fmt
    using strings

    recordNames := make([dynamic]string)

    collectionExists, colCheckError := check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return recordNames, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError := check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil {
        return recordNames,     make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    data, readSuccess := read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess {
        return recordNames, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    // Skip metadata section if present
    content := string(data)
    if metadataEnd := index(content, METADATA_END);
       metadataEnd >= 0 {
        content = content[metadataEnd + len(METADATA_END):]
    }

    clusterBlocks := split(content, "},")
    defer delete(clusterBlocks)

    for c in clusterBlocks {
        if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
            lines := split(c, "\n")
            defer delete(lines)

            for line in lines {
                trimmedLine := trim_space(line)
                if len(trimmedLine) > 0 &&
                   !has_prefix(trimmedLine, "cluster_name") &&
                   !has_prefix(trimmedLine, "cluster_id") &&
                   !contains(trimmedLine, "#") &&  // Skip comment lines
                   !contains(trimmedLine, METADATA_START) &&
                   !contains(trimmedLine, METADATA_END) &&
                   contains(trimmedLine, ":") {
                    // Extract the record name (everything before the first colon)
                    parts := split(trimmedLine, ":")
                    if len(parts) >= 2 {
                        recordName := trim_space(parts[0])
                        append(&recordNames, clone(recordName))
                    }
                }
            }
            break
        }
    }

    return recordNames, no_error()
}

@(require_results)
get_all_records_in_cluster_by_type :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> ([dynamic]lib.Record, ^lib.Error) {
    using lib
    using fmt
    using strings

    records := make([dynamic]Record)

    collectionExists, colCheckError := check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return records, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists , cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return records, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    data, readSuccess := read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess {
        return records, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    clusterBlocks := split(string(data), "},")
    defer delete(clusterBlocks)

    targetType := RecordDataTypesStrings[record.type]

    for c in clusterBlocks {
        if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
            lines := split(c, "\n")
            defer delete(lines)

            for line in lines {
                trimmedLine := trim_space(line)
                if len(trimmedLine) == 0 ||
                   has_prefix(trimmedLine, "cluster_name") ||
                   has_prefix(trimmedLine, "cluster_id") ||
                   contains(trimmedLine, "#") {
                    continue
                }

                if contains(trimmedLine, ":") {
                    // Parse the record to check its type
                    parsedRecord, parserError := parse_record(trimmedLine)
                    if parserError != nil {
                        return records, parserError
                    }else{
                        if parsedRecord.type == record.type {
                            append(&records, parsedRecord)
                        }
                    }
                }
            }
            break
        }
    }

    return records, no_error()
}

//find and return the passed in records value as a string
//Remember to delete() the the return value from the calling procedure
@(require_results)
get_record_value :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) ->(string, ^lib.Error) {
    using lib
    using fmt
    using strings

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return get_err_msg(.COLLECTION_NOT_FOUND), make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError!= nil{
        return get_err_msg(.CLUSTER_NOT_FOUND), make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return get_err_msg(.RECORD_NOT_FOUND), make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)
	if !readSuccess {
		return get_err_msg(.COLLECTION_CANNOT_READ), make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	content := string(data)
	defer delete(content)

	clusterBlocks := split(content, "},")
	defer delete(clusterBlocks)

	for c in clusterBlocks {
		c := trim_space(c)
		if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
			// Found the correct cluster, now look for the record
			lines := split(c, "\n")
			defer delete(lines)

			for line in lines {
				trimmedLine := trim_space(line)

				// Skip empty lines and identifier records
				if len(trimmedLine) == 0 ||
				   has_prefix(trimmedLine, "cluster_name :identifier:") ||
				   has_prefix(trimmedLine, "cluster_id :identifier:") {
					continue
				}
				if has_prefix(trimmedLine, tprintf("%s :", record.name)) {
					// Split by the record type pattern to get the value
					parts := split(trimmedLine, ":")
					if len(parts) >= 3 {
						// The value is everything after the second colon
						recordValue := trim_space(parts[2])
						return clone(recordValue), no_error()
					}
				}
			}
		}
	}

	return get_err_msg(.RECORD_CANNOT_GET_VALUE), make_new_err(.RECORD_CANNOT_GET_VALUE, get_caller_location())
}

//Used to ensure that the passed in records type is valid and if its shorthand assign the value as the longhand
//e.g if INT then assign INTEGER. Returns the type
//Remember to delete() the return value in the calling procedure
@(require_results)
verify_record_data_type_is_valid :: proc(record: ^lib.Record) -> string {
    using lib
    using fmt
    using strings

	for type in RecordDataTypes {
		if record.type == type {
			#partial switch (record.type)
			{ 	//The first 8 cases handle if the type is shorthand
			case .STR:
				record.type = .STRING
				break
			case .INT:
				record.type = .INTEGER
				break
			case .FLT:
				record.type = .FLOAT
				break
			case .BOOL:
				record.type = .BOOLEAN
				break
			case .STR_ARRAY:
				record.type = .STRING_ARRAY
				break
			case .INT_ARRAY:
				record.type = .INTEGER_ARRAY
				break
			case .FLT_ARRAY:
				record.type = .FLOAT_ARRAY
				break
			case .BOOL_ARRAY:
				record.type = .BOOLEAN_ARRAY
				break
			case:
				//If not a valid shorhand just set the type to whatever it is so long as its valid in general
				record.type = type
				break
			}
		}
	}
	return clone(RecordDataTypesStrings[record.type])
}

//Returns the data type of the passed in record
@(require_results)
get_record_type :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> ( string, ^lib.Error) {
    using lib
    using fmt
    using strings

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists,colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return get_err_msg(.COLLECTION_NOT_FOUND), make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists ||cluCheckError != nil{
        return get_err_msg(.CLUSTER_NOT_FOUND), make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }
    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return get_err_msg(.RECORD_NOT_FOUND), make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)

	if !readSuccess {
		return get_err_msg(.COLLECTION_CANNOT_READ), make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	clusters := split(string(data), "},")
	defer delete(clusters)

	for c in clusters {
		//check for cluster
		if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
			lines := split(c, "\n")
			for line in lines {
				line := trim_space(line)

				// Skip empty lines and identifier records
				if len(line) == 0 ||
				   has_prefix(line, "cluster_name :identifier:") ||
				   has_prefix(line, "cluster_id :identifier:") {
					continue
				}

				if has_prefix(line, tprintf("%s :", record.name)) {
					// Split the line into parts using ":"
					parts := split(line, ":")
					if len(parts) >= 2 {
						// Return the type of the record
						return clone(trim_space(parts[1])), no_error()
					}
				}
			}
		}
	}

	return get_err_msg(.RECORD_CANNOT_GET_TYPE), make_new_err(.RECORD_CANNOT_GET_TYPE, get_caller_location())
}

@(require_results)
set_record_value ::proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> ^lib.Error {
    using lib
    using fmt
    using strings


    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess{
        return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

   	recordType, getTypeSuccess := get_record_type(projectContext, collection, cluster, record)

	intArrayValue:= make([dynamic]int, 0)
	defer delete(intArrayValue)

	fltArrayValue:= make([dynamic]f64, 0)
	defer delete(fltArrayValue)

	boolArrayValue:= make([dynamic]bool, 0)
	defer delete(boolArrayValue)

	charArrayValue:= make([dynamic]rune, 0)
	defer delete(charArrayValue)

	//Freeing memory for these at bottom of procedure
	stringArrayValue, timeArrayValue, dateTimeArrayValue, dateArrayValue, uuidArrayValue:[dynamic]string
	defer delete(intArrayValue)
	defer delete(fltArrayValue)
	defer delete(boolArrayValue)
	defer delete(stringArrayValue)
	defer delete(dateArrayValue)
	defer delete(timeArrayValue)
	defer delete(dateTimeArrayValue)
	defer delete(uuidArrayValue)

	//Standard value allocation
	valueAny: any = 0
	ok: ^Error
	setValueOk := false

	switch (recordType) {
	//Single value primitives and complex
	case RecordDataTypesStrings[.INTEGER]:
		record.type = .INTEGER
		valueAny, ok = convert_record_value_to_int(record.value)
		if ok != nil {
		    return ok
		}
		setValueOk = true
		break
	case RecordDataTypesStrings[.FLOAT]:
		record.type = .FLOAT
		valueAny, ok = covert_record_to_float(record.value)
		if ok != nil {
		    return ok
		}
		setValueOk = true
		break
	case RecordDataTypesStrings[.BOOLEAN]:
		record.type = .BOOLEAN
		valueAny, ok = convert_record_value_to_bool(record.value)
		if ok != nil {
		    return ok
		}
		setValueOk = true
		break
	case RecordDataTypesStrings[.STRING]:
		record.type = .STRING
		valueAny = append_qoutations(record.value)
		setValueOk = true
		break
	case RecordDataTypesStrings[.CHAR]:
		record.type = .CHAR
		if len(record.value) != 1 {
			setValueOk = false
		} else {
			valueAny = append_single_qoutations_string(record.value)
			setValueOk = true
		}
		break
	case RecordDataTypesStrings[.DATE]:
		record.type = .DATE
		date, ok := convert_record_value_to_date(record.value)
		if ok != nil {
		    return ok
		}

		setValueOk = true
		valueAny = date

		break
	case RecordDataTypesStrings[.TIME]:
		record.type = .TIME
		time, ok := convert_record_value_to_time(record.value)
		if ok != nil {
		    return ok
		}
		setValueOk = true
		valueAny = time
		break
	case RecordDataTypesStrings[.DATETIME]:
		record.type = .DATETIME
		dateTime, ok := convert_record_value_to_datetime(record.value)
		if ok != nil {
		    return ok
		}
		setValueOk = true
		valueAny = dateTime
		break
	case RecordDataTypesStrings[.UUID]:
		record.type = .UUID
		uuid, ok := convert_record_value_to_uuid(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = uuid
		setValueOk = true
		break
	case RecordDataTypesStrings[.NULL]:
		record.type = .NULL
		valueAny = RecordDataTypesStrings[.NULL]
		setValueOk = true
		break

	//Arrays of primitives and complex
	case RecordDataTypesStrings[.INTEGER_ARRAY]:
		record.type = .INTEGER_ARRAY
		verifiedValue := verify_array_values(record)
		if verifiedValue != nil{
			return verifiedValue
		}
		intArrayValue, ok := convert_record_value_to_int_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = intArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.FLOAT_ARRAY]:
		record.type = .FLOAT_ARRAY
		verifiedValue := verify_array_values(record)
		if verifiedValue != nil {
			return verifiedValue
		}
		fltArrayValue, ok := convert_record_value_to_float_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = fltArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.BOOLEAN_ARRAY]:
		record.type = .BOOLEAN_ARRAY
		verifiedValue := verify_array_values(record)
		if verifiedValue != nil {
			return verifiedValue
		}
		boolArrayValue, ok := convert_record_value_to_bool_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = boolArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.STRING_ARRAY]:
		record.type = .STRING_ARRAY
		stringArrayValue, ok := convert_record_value_to_string_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = stringArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.CHAR_ARRAY]:
		record.type = .CHAR_ARRAY
		charArrayValue, ok := convert_record_value_to_char_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = charArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.DATE_ARRAY]:
		record.type = .DATE_ARRAY
		dateArrayValue, ok := convert_record_value_to_date_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = dateArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.TIME_ARRAY]:
		record.type = .TIME_ARRAY
		timeArrayValue, ok := convert_record_value_to_time_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = timeArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.DATETIME_ARRAY]:
		record.type = .DATETIME_ARRAY
		dateTimeArrayValue, ok := convert_record_value_to_datetime_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = dateTimeArrayValue
		setValueOk = true
		break
	case RecordDataTypesStrings[.UUID_ARRAY]:
		record.type = .UUID_ARRAY
		uuidArrayValue, ok := convert_record_value_to_uuid_array(record.value)
		if ok != nil {
		    return ok
		}
		valueAny = uuidArrayValue
		setValueOk = true
		break
	}

	if !setValueOk {
		return make_new_err(.RECORD_INVALID_VALUE, get_caller_location())
	}


	updateSuccess:= update_record_value(projectContext,collection, cluster, record, valueAny)
	if updateSuccess != nil  {
	    return make_new_err(.RECORD_CANNOT_UPDATE, get_caller_location())
	}

	return no_error()
}

@(cold, require_results)
get_record_value_size :: proc(projectContext: ^lib.ProjectContext,collection:^lib.Collection, cluster:^lib.Cluster, record: ^lib.Record) -> (int, ^lib.Error) {
    using lib
    using fmt
    using strings


    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return -1, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return -2, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return -3, make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess{
        return -4, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

	clusterBlocks := split(string(data), "},")
	defer delete(clusterBlocks)

	for c in clusterBlocks {
		if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
			lines := split(c, "\n")
			defer delete(lines)
			for line in lines {
				parts := split(line, ":")
				defer delete(parts)
				if has_prefix(line, tprintf("\t%s", record.name)) {
					//added the \t to the prefix because all records are indented in the plain text collection file - Marshall Burns Jan 2025
					parts := split(line, ":")
					if len(parts) == 3 {
						recordValue := trim_space(join(parts[2:], ":"))
						return len(recordValue), no_error()
					}
				}
			}
		}
	}
	return -5, make_new_err(.RECORD_CANNOT_GET_VALUE_SIZE, get_caller_location())
   }


//returns the number of records within the passed in cluster
@(cold, require_results)
get_record_count_within_cluster :: proc(projectContext: ^lib.ProjectContext,collection:^lib.Collection, cluster:^lib.Cluster) -> (i64, ^lib.Error) {
    using lib
    using fmt
    using strings

    recordCount:i64= 0

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return -1, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return -2, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess{
        return -4, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

	clusterBlocks := split(string(data), "},")
	defer delete(clusterBlocks)

	for c in clusterBlocks {
		if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
			lines := split(c, "\n")
			defer delete(lines)

			for line in lines {
				trimmedLine := trim_space(line)
				if len(trimmedLine) > 0 &&
				   !has_prefix(trimmedLine, "cluster_name") &&
				   !has_prefix(trimmedLine, "cluster_id") &&
				   !contains(trimmedLine, "#") &&
				   !contains(trimmedLine, METADATA_START) &&
				   !contains(trimmedLine, METADATA_END) &&
				   contains(trimmedLine, ":") {
					recordCount += 1
				}
			}
		}
	}

	return recordCount, no_error()
}

//reads over the passed in collection file and returns the number of records in that collection
//returns the number of record within an entire collection
@(cold, require_results)
get_record_count_within_collection :: proc( projectContext: ^lib.ProjectContext,collection:^lib.Collection, cluster:^lib.Cluster, record: ^lib.Record) -> (int, ^lib.Error) {
    using lib
    using fmt
    using strings

    recordCount:= 0

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return -1, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return -2, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    recordExists, recCheckError:= check_if_record_exists_in_cluster(projectContext, collection, cluster, record)
    if !recordExists || recCheckError != nil{
        return -3, make_new_err(.RECORD_NOT_FOUND, get_caller_location())
    }

    data, readSuccess:= read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess{
        return -4, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

	content := string(data)
	defer delete(content)

	// Skip metadata section
	if metadataEnd := index(content,METADATA_END);
	   metadataEnd >= 0 {
		content = content[metadataEnd + len(METADATA_END):]
	}

	clusterBlocks := split(content, "},")
	defer delete(clusterBlocks)


	for c in clusterBlocks {
		if !contains(c, "cluster_name :identifier:") {
			continue // Skip non-cluster content
		}
		lines := split(c, "\n")
		defer delete(lines)

		for line in lines {
			trimmedLine := trim_space(line)
			if len(trimmedLine) > 0 &&
			   !has_prefix(trimmedLine, "cluster_name") &&
			   !has_prefix(trimmedLine, "cluster_id") &&
			   contains(trimmedLine, ":") &&
			   !contains(trimmedLine, METADATA_START) &&
			   !contains(trimmedLine, METADATA_END) {
				recordCount += 1
			}
		}
	}

	return recordCount,  no_error()
}

//Reads over the passed in collection and a specific cluster for a record by name, returns true if found
@(require_results)
check_if_record_exists_in_cluster :: proc(projectContext: ^lib.ProjectContext,collection:^lib.Collection, cluster:^lib.Cluster, record: ^lib.Record) -> (bool, ^lib.Error) {
	using lib
	using fmt
	using strings

	parsedCluster, err := parse_specific_cluster(projectContext, collection, cluster.name)
	defer free(&parsedCluster)
	foundRecord := get_record_by_name(&parsedCluster, record.name)
	return foundRecord != nil, no_error()
}

//Finds and Returns the Record that matches the passed in record ID in the passed in cluster in the passed in collection
@(require_results)
get_record_by_id :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, recordID: i64) -> (lib.Record, ^lib.Error) {
    using lib
    using fmt
    using strings


    collectionExists, colCheckError:= check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return Record{}, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists, cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return Record{}, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    data, readSuccess := read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess {
        return Record{}, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    clusterBlocks := split(string(data), "},")
    defer delete(clusterBlocks)

    for c in clusterBlocks {
        if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
            lines := split(c, "\n")
            defer delete(lines)

            currentID := i64(0) // Records start at ID 0 becuase the increment_record_id() proc does it
            for line in lines {
                trimmedLine := trim_space(line)

                // Skip metadata and empty lines
                if len(trimmedLine) == 0 ||
                   has_prefix(trimmedLine, "cluster_name") ||
                   has_prefix(trimmedLine, "cluster_id") ||
                   contains(trimmedLine, "#") {
                    continue
                }

                // If this is a record line and matches our ID
                if contains(trimmedLine, ":") && currentID == recordID {
                    parsedRecord, parserError:= parse_record(trimmedLine)
                    if parserError != nil{
                        return Record{}, parserError
                    }
                    return parsedRecord, no_error()
                }

                //Increment records ID
                if contains(trimmedLine, ":") {
                    currentID += 1
                }
            }
            break
        }
    }

    return Record{}, make_new_err(.RECORD_CANNOT_GET_BY_ID, get_caller_location())
}

//Finds and returns all Records that match the results of the passed in pagination(data partitioning) and filtering args
// Example since I am just learning this shit:
// If you have 100 records and call: get_filtered_records(..., limit: 10, offset: 20)
// - offset = 20 means "skip the first 20 records"
// - limit = 10 means "only return 10 records maximum"
// Result: You get records #21, #22, #23... up to #30 (10 records total)
@(require_results)
get_filtered_records :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, recordType: string = "", limit: int = -1, offset: int = 0) -> ([dynamic]lib.Record, ^lib.Error) {
    using lib
    using fmt
    using strings

    records := make([dynamic]Record)

    // Get all records or filter by type
    if recordType != "" {
        // User wants only records of a specific type
        newRecord := make_new_record(collection, cluster, "")
        defer free(newRecord)

        // Convert the string type name to the internal enum format
        typeFound := false
        for dataTypeStringValue, dataTypeToken in RecordDataTypesStrings {
            if dataTypeStringValue == recordType {
                newRecord.type = dataTypeToken
                typeFound = true
                break
            }
        }

        if !typeFound {
            // Invalid type specified
            return records, make_new_err(.RECORD_CANNOT_FILTER, get_caller_location())
        }

        // Get only records that match the requested type
        typeRecords, typeSuccess := get_all_records_in_cluster_by_type(projectContext, collection, cluster, newRecord)
        if typeSuccess ==nil {
            records = typeRecords
        }else{
             return records, make_new_err(.RECORD_CANNOT_FILTER, get_caller_location())
        }
    } else {
        // User wants ALL record types - no filtering by type
        allRecords, allSuccess := get_all_records_in_cluster(projectContext, collection, cluster)
        if allSuccess == nil {
            records = allRecords
        }else{
            return records, make_new_err(.RECORD_CANNOT_FILTER, get_caller_location())
        }
    }

    // Apply pagination if specified
    if(limit > 0 || offset > 0) {
        totalRecords := len(records)

        // Apply offset
        if offset > 0 && offset < totalRecords {
            newRecords := make([dynamic]Record)
            for i in offset..<len(records) {
                append(&newRecords, records[i])
            }
            delete(records)
            records = newRecords
        } else if offset >= totalRecords {
            // Offset is beyond available records
            delete(records)
            records = make([dynamic]Record)
        }

        // Apply limit
        if limit > 0 && len(records) > limit {
            newRecords := make([dynamic]Record)
            for i in 0..<limit {
                append(&newRecords, records[i])
            }
            delete(records)
            records = newRecords
        }
    }

    return records, no_error()
}

// Helper proc that gets returns single Record in the passed in Cluster in the passed in Collection
@(require_results)
get_all_records_in_cluster :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster) -> ([dynamic]lib.Record, ^lib.Error) {
    using lib
    using fmt
    using strings

    records := make([dynamic]Record)
    success := false

    collectionExists, colCheckError := check_if_collection_exists(projectContext, collection)
    if !collectionExists || colCheckError != nil{
        return records, make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    clusterExists ,cluCheckError:= check_if_cluster_exsists_in_collection(projectContext, collection, cluster)
    if !clusterExists || cluCheckError != nil{
        return records, make_new_err(.CLUSTER_NOT_FOUND, get_caller_location())
    }

    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    data, readSuccess := read_file(collectionPath, get_caller_location())
    defer delete(data)
    if !readSuccess {
        return records, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
    }

    clusterBlocks := split(string(data), "},")
    defer delete(clusterBlocks)

    for c in clusterBlocks {
        if contains(c, tprintf("cluster_name :identifier: %s", cluster.name)) {
            lines := split(c, "\n")
            defer delete(lines)

            for line in lines {
                trimmedLine := trim_space(line)

                // Skip metadata and empty lines
                if len(trimmedLine) == 0 ||
                   has_prefix(trimmedLine, "cluster_name") ||
                   has_prefix(trimmedLine, "cluster_id") ||
                   contains(trimmedLine, "#") {
                    continue
                }

                // Parse valid record lines
                if contains(trimmedLine, ":") {
                    parsedRecord, parseError := parse_record(trimmedLine)
                    if parseError != nil {
                        return records, parseError
                    }
                    append(&records, parsedRecord)
                }
            }
            break
        }
    }

    return records, no_error()
}

// Searches and filters records based on criteria, applies sorting, and returns paginated results
@(require_results)
search_and_filter_records :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, criteria: lib.SearchCriteria, limit: int = -1, offset: int = 0) -> ([dynamic]lib.Record, bool) {
    using lib
    using strings

    records := make([dynamic]Record)
    success := false

    // Get all records first
    allRecords, getAllSuccess := get_all_records_in_cluster(projectContext, collection, cluster)
    if getAllSuccess != nil{
        return records, success
    }
    defer delete(allRecords)

    // Apply filters
    filteredRecords := make([dynamic]Record)
    defer delete(filteredRecords)

    for record in allRecords {
        if matches_search_criteria(record, criteria) {
            append(&filteredRecords, record)
        }
    }

    // Apply sorting BEFORE pagination
    sort_records(&filteredRecords, criteria.sortField, criteria.sortOrder)

    // Apply pagination
    startIndex := offset
    endIndex := len(filteredRecords)

    if limit > 0 && startIndex + limit < endIndex {
        endIndex = startIndex + limit
    }

    if startIndex < len(filteredRecords) && startIndex >= 0 {
        for i in startIndex..<min(endIndex, len(filteredRecords)) {
            append(&records, filteredRecords[i])
        }
        success = true
    }

    return records, success
}

// Checks if a record matches the given search criteria (name, value, type filters)
@(require_results)
matches_search_criteria :: proc(record: lib.Record, criteria: lib.SearchCriteria) -> bool {
    using lib
    using strings

    // Name pattern matching - case insensitive contains check
    if len(criteria.namePattern) > 0 {
        recordNameLower := to_lower(record.name)
        patternLower := to_lower(criteria.namePattern)
        if !contains(recordNameLower, patternLower) {
            return false
        }
    }

    // Value pattern matching - case insensitive contains check
    if len(criteria.valuePattern) > 0 {
        recordValueLower := to_lower(record.value)
        patternLower := to_lower(criteria.valuePattern)
        if !contains(recordValueLower, patternLower) {
            return false
        }
    }

    if criteria.typeFilter != .INVALID && record.type != criteria.typeFilter {
        return false
    }

    // Numeric range filtering
    if criteria.valueRange.hasMin || criteria.valueRange.hasMax {
        if !matches_numeric_range(record, criteria.valueRange) {
            return false
        }
    }

    return true
}

// Validates if a numeric record's value falls within the specified min/max range
@(require_results)
matches_numeric_range :: proc(record: lib.Record, valueRange: struct{min: string, max: string, hasMin: bool, hasMax: bool}) -> bool {

    // Only apply to numeric types
    if record.type != .INTEGER && record.type != .FLOAT {
        return true
    }

    // Parse record value as float for comparison
    recordValue, parseOk := strconv.parse_f64(record.value)
    if !parseOk {
        return false // If we can't parse the record value, exclude it from range filtering
    }

    if valueRange.hasMin {
        minValue, minOk := strconv.parse_f64(valueRange.min)
        if !minOk {
            return false // Invalid min value in criteria
        }
        if recordValue < minValue {
            return false
        }
    }

    if valueRange.hasMax {
        maxValue, maxOk := strconv.parse_f64(valueRange.max)
        if !maxOk {
            return false // Invalid max value in criteria
        }
        if recordValue > maxValue {
            return false
        }
    }

    return true
}

// Sorts an array of records using quicksort algorithm by specified field and order
sort_records :: proc(records: ^[dynamic]lib.Record, sortField: lib.SortField, sortOrder: lib.SortOrder) {
    using lib

    if len(records^) < 2 {
        return // Nothing to sort
    }

    // Implement quicksort for better performance
    quicksort_records(records, 0, len(records^) - 1, sortField, sortOrder)
}

// Recursively sorts records using quicksort partitioning between low and high indices
quicksort_records :: proc(records: ^[dynamic]lib.Record, low: int, high: int, sortField: lib.SortField, sortOrder: lib.SortOrder) {
    if low < high {
        pi := partition_records(records, low, high, sortField, sortOrder)
        quicksort_records(records, low, pi - 1, sortField, sortOrder)
        quicksort_records(records, pi + 1, high, sortField, sortOrder)
    }
}

// Partitions records array around a pivot for quicksort, placing smaller elements before pivot
partition_records :: proc(records: ^[dynamic]lib.Record, low: int, high: int, sortField: lib.SortField, sortOrder: lib.SortOrder) -> int {
    using lib
    using strings

    pivot := records^[high]
    i := low - 1

    for j in low..<high {
        shouldSwap := false

        switch sortField {
        case .NAME:
            if sortOrder == .ASC {
                shouldSwap = records^[j].name <= pivot.name
            } else {
                shouldSwap = records^[j].name >= pivot.name
            }
        case .VALUE:
            if sortOrder == .ASC {
                shouldSwap = records^[j].value <= pivot.value
            } else {
                shouldSwap = records^[j].value >= pivot.value
            }
        case .TYPE:
            if sortOrder == .ASC {
                shouldSwap = int(records^[j].type) <= int(pivot.type)
            } else {
                shouldSwap = int(records^[j].type) >= int(pivot.type)
            }
        case .ID:
            if sortOrder == .ASC {
                shouldSwap = records^[j].id <= pivot.id
            } else {
                shouldSwap = records^[j].id >= pivot.id
            }
        }

        if shouldSwap {
            i += 1
            records^[i], records^[j] = records^[j], records^[i]
        }
    }

    records^[i + 1], records^[high] = records^[high], records^[i + 1]
    return i + 1
}

// helper used to parse records into 3 parts, the name, type and value. Appends to a struct then returns
// remember to delete the return values in the calling procedure
@(require_results)
parse_record :: proc(recordAsString: string) -> (lib.Record, ^lib.Error) {
    using lib
    using strings
    using strings

    newRecordDataType: RecordDataTypes

	recordParts := split(recordAsString, ":")
	if len(recordParts) < 2 {
		return Record{}, make_new_err(.RECORD_CANNOT_PARSE, get_caller_location())
	}

	recordName := trim_space(recordParts[0])
	recordType := trim_space(recordParts[1])
	recordValue := trim_space(recordParts[2])

	// Find the enum value by looking up the string in the RecordDataTypesStrings map
	for  dataTypeStringValue, dataTypeToken in RecordDataTypesStrings {
		if dataTypeStringValue == recordType {
			newRecordDataType= dataTypeToken
			break
		}
	}

	return Record {
        name = clone(recordName),
        type = newRecordDataType,
        typeAsString = clone(RecordDataTypesStrings[newRecordDataType]),
        value = clone(recordValue)
	}, no_error()
}


@(require_results)
valid_record_name :: proc(record: ^lib.Record) -> (bool, ^lib.Error){
    using lib

    //Name len check and invalid char check
    if len(record.name) > MAX_DATA_STRUCURE_NAME_LEN || contains_disallowed_chars(record.name) do return false, make_new_err(.CLUSTER_NAME_INVALID, get_caller_location())

    return true, no_error()
}
