package data

import "core:os"
import "core:fmt"
import "core:strings"
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
            collections within the OstrichDB engine.
*********************************************************/

//Allocates memory for a new lib.Collection, then returns a pointer to it. Remember to free() in calling procedure
@(require_results)
make_new_collection :: proc(name:string, type: lib.CollectionType) -> ^lib.Collection{
    using lib

    collection := new(lib.Collection)
    collection.name = name
    collection.type = type
    collection.numberOfClusters = 0
    collection.clusters = make([dynamic]Cluster, 0)

    return collection
}

//Creates a collection file
@(require_results)
create_collection_file :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection) -> ^lib.Error {
    using lib

     collectionPath := get_specific_collection_full_path(projectContext, collection)
     defer delete(collectionPath)
     // Check if a collection of the passed in name already exists
     collectionAlreadtExists, checkError:=  check_if_collection_exists(projectContext,collection)
     if collectionAlreadtExists || checkError != nil{
         return make_new_err(.COLLECTION_ALREADY_EXISTS, get_caller_location())
     }

    file, creationSuccess:= os.open(collectionPath, os.O_CREATE, 0o666)
	defer os.close(file)

    appendSuccess:= append_metadata_header_to_collection(projectContext, collection)
    if appendSuccess !=  nil{
        return make_new_err(.COLLECTION_CANNOT_APPEND_METADATA, get_caller_location())
    }

	if creationSuccess != 0{
		return make_new_err(.COLLECTION_CANNOT_CREATE, get_caller_location())
	}

	appendMetadataSuccess:= init_metadate_in_new_collection(projectContext, collection)
	if appendMetadataSuccess != nil {
	    return make_new_err(.COLLECTION_CANNOT_APPEND_METADATA, get_caller_location())
	}

	return no_error()
}

@(require_results)
erase_collection ::proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection) -> ^lib.Error{
   	using lib

    collectionExists, checkError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || checkError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
	defer delete(collectionPath)

	deleteSuccess := os.remove(collectionPath)
	if deleteSuccess != 0 {
        return make_new_err(.COLLECTION_CANNOT_DELETE, get_caller_location())
	}

	return no_error()
}

//Renames the passed in collection.name to the new name
@(require_results)
rename_collection :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection, newName:string) -> ^lib.Error {
    using lib

    //Check if a collection with the name that the user wants to rename does in fact check_if_collection_exists
    collectionExists, checkError:= check_if_collection_exists(projectContext,collection)
   if !collectionExists || checkError != nil{
        return make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    //Now check if there is already a collection using the name "newName"
    newCollection:= make_new_collection(newName, .STANDARD)
    defer free(newCollection)
    collectionAlreadyExists, newCheckError:= check_if_collection_exists(projectContext,newCollection)
    if collectionAlreadyExists || newCheckError != nil{
        return make_new_err(.COLLECTION_ALREADY_EXISTS, get_caller_location())
    }

	collectionPath := lib.get_specific_collection_full_path(projectContext, collection)
	defer delete(collectionPath)

    renameSuccess := lib.rename_file(collectionPath, fmt.tprintf("%s.ostrichdb", newName))
    if !renameSuccess  {
       return make_new_err(.COLLECTION_CANNOT_UPDATE, get_caller_location())
    }

	return no_error()
}

//Returns the all content within the body of a Collection
@(require_results)
fetch_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (ParsedCollection, ^lib.Error) {
    using lib
    using strings

    parsedCollection, parseError := parse_collection_with_options(projectContext, collection,FULL_COLLECTION_PARSE)
	parsedCollection.name = collection.name

	return  parsedCollection, no_error()
}

//Deletes all data from the body of a Collection while "retaining" the metadata header
@(require_results, deprecated="This legacy procedure has been deprectated")
purge_collection :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection) -> ^lib.Error {
	using lib
	using strings

	parsedCollection, parseError := parse_entire_collection(projectContext, collection)

	// Write back only the header
	writeSuccess := write_to_file(parsedCollection.filePath, transmute([]byte)parsedCollection.metadataHeader.rawContent, get_caller_location())
	if !writeSuccess {
		return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return no_error()
}

//Reads over all standard collections, appends their names and returns them
//Dont forget to free the memory in the calling procedure
@(require_results)
get_all_collection_names :: proc(projectContext: ^lib.ProjectContext) -> ([dynamic]string, ^lib.Error){
    using lib

    collectionPath:= lib.get_collections_path(projectContext)
    collectionArray:= make([dynamic]string, 0)
    standardCollectionDir, openDirError :=os.open(collectionPath)
    collections, readDirError:= os.read_dir(standardCollectionDir, 1)
    defer os.file_info_slice_delete(collections)

    if readDirError!=nil{
        return collectionArray, make_new_err(.STANDARD_CANNOT_READ_DIRECTORY, get_caller_location())
    }

    for collection in collections{
        append(&collectionArray, collection.name)
    }

    return collectionArray, no_error()
}

//See if the passed in collection exists in the path
@(require_results)
check_if_collection_exists :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (bool, ^lib.Error) {
    using lib

    exists:= false

    collectionPath:= fmt.tprintf("%scollections/",projectContext.basePath)

    dir, openError:= os.open(collectionPath)
    if  openError != nil{
        return exists, make_new_err(.STANDARD_CANNOT_OPEN_DIRECTORY, get_caller_location())
    }
    files, readError := os.read_dir(dir, -1)
    defer os.file_info_slice_delete(files)
    if  readError != nil{
        return exists, make_new_err(.STANDARD_CANNOT_READ_DIRECTORY, get_caller_location())
    }

    for file in files {
            if file.name == fmt.tprintf("%s%s", collection.name, OST_EXT){
                exists = true
                break
            }
        }

        return exists, no_error()
}

//gets the number of  collections
@(require_results)
get_collection_count :: proc(projectContext: ^lib.ProjectContext) -> int {
	using lib

	collectionCount:= 0

	collectionDir, openError := os.open(get_collections_path(projectContext))
	defer os.close(collectionDir)

	collections, dirReadSuccess := os.read_dir(collectionDir, -1)
	defer delete(collections)
	for collection in collections  {
		if strings.contains(collection.name, OST_EXT) {
		    collectionCount+=1
		}
	}

	return collectionCount
}

//Checks if the passed in collection.name is valid
@(require_results)
validate_collection_name :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (bool, ^lib.Error) {
	using lib

	//CHECK#1: check collection name length
	nameAsBytes := transmute([]byte)collection.name
	if len(nameAsBytes) > MAX_COLLECTION_NAME_LENGTH {
		return false, make_new_err(.COLLECTION_INVALID_NAME, get_caller_location())
	}

	// CHECK#2: check if the file already exists
	collectionExists, colCheckError :=check_if_collection_exists(projectContext,collection)
	if collectionExists  || colCheckError != nil{
	    return false, make_new_err(.COLLECTION_ALREADY_EXISTS, get_caller_location())
	}

	//CHECK#3: check if the name has special chars
	invalidChars := "[]{}()<>;:.,?/\\|`~!@#$%^&*+="
	defer delete(invalidChars)

	for c := 0; c < len(collection.name); c += 1 {
		if strings.contains_any(collection.name, invalidChars) {
			return false, make_new_err(.COLLECTION_INVALID_NAME, get_caller_location())
		}
	}

	return true, no_error()
}
