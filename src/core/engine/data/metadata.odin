package data

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"
import "core:crypto"
import "core:crypto/hash"
import "core:math/rand"
import "../../config"
import lib "../../../library"
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
            metadata within the OstrichDB engine.
*********************************************************/

// Converts CollectionMetadata back to raw metadata header string
@(require_results)
serialize_metadata_header :: proc(metadata: CollectionMetadata) -> string {
    using lib
    using fmt
    using strings

    headerLines := make([dynamic]string)
    // defer delete(headerLines)

    // Add metadata start marker
    append(&headerLines, METADATA_START)


    append(&headerLines, tprintf("# Encryption State: %s\n", metadata.encryptionState))
    append(&headerLines, tprintf("# File Format Version: %s\n", metadata.fileFormatVersion))
    append(&headerLines, tprintf("# Date of Creation: %s\n", metadata.dateCreation))
    append(&headerLines, tprintf("# Date Last Modified: %s\n", metadata.dateModified))
    append(&headerLines, tprintf("# File Size: %s\n", metadata.fileSize))
    append(&headerLines, tprintf("# Checksum: %s\n", metadata.checksum))

    // Add metadata end marker
    append(&headerLines, METADATA_END)

    return join(headerLines[:], "")
}

// Reconstructs a complete collection from metadata and body
@(require_results)
reconstruct_collection :: proc(metadata: CollectionMetadata, body: string) -> string {
    using strings

    serializedMetadata := serialize_metadata_header(metadata)
    // defer delete(serializedMetadata)

    if len(body) == 0 {
        return clone(serializedMetadata)
    }

    return concatenate([]string{serializedMetadata, body})
}

// Updates a specific field in CollectionMetadata struct
update_metadata_field :: proc(metadata: ^CollectionMetadata, field: lib.MetadataField, value: string) {
    using lib
    using strings

    #partial switch field {
    case .ENCRYPTION_STATE:
        delete(metadata.encryptionState)
        metadata.encryptionState = value
    case .FILE_FORMAT_VERSION:
        delete(metadata.fileFormatVersion)
        metadata.fileFormatVersion = value
    case .DATE_CREATION:
        delete(metadata.dateCreation)
        metadata.dateCreation = value
    case .DATE_MODIFIED:
        delete(metadata.dateModified)
        metadata.dateModified = value
    case .FILE_SIZE:
        delete(metadata.fileSize)
        metadata.fileSize = value
    case .CHECKSUM:
        delete(metadata.checksum)
        checksumClone:=clone(value)
        metadata.checksum = checksumClone
    }
}

//Sets the collections file format version(FFV)
@(require_results)
set_file_format_version :: proc() -> (string, ^lib.Error) {
	using lib

    ffvData, ffvError := get_file_format_version()
	defer delete(ffvData)
	if ffvError != nil{
	    return get_err_msg(.METADATA_CANNOT_SET_FFV), make_new_err(.METADATA_CANNOT_SET_FFV, get_caller_location())
	}
	return strings.clone(string(ffvData)), no_error()
}

//Gets the file format version from the file format version file
@(require_results)
get_file_format_version :: proc() -> ([]u8, ^lib.Error) {
	using lib
	using fmt

	versionFilePath := tprintf("./%s", "version")

	file, openSuccess := os.open(versionFilePath)
	if openSuccess != 0 {
		return []u8{}, make_new_err(.STANDARD_CANNOT_OPEN_FILE, get_caller_location())
	}

	data, readError := os.read_entire_file(versionFilePath)
	if readError == false {
		return []u8{}, make_new_err(.STANDARD_CANNOT_READ_FILE, get_caller_location())
	}

	os.close(file)
	return data, no_error()
}

//this will get the size of the file and then subtract the size of the metadata header
//then return the difference
@(require_results)
subtract_metadata_size_from_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (int, ^lib.Error) {
	using lib

	collectionPath:= get_specific_collection_full_path(projectContext, collection)
	defer delete(collectionPath)

	collectionInfo:= get_file_info(collectionPath)
	defer os.file_info_delete(collectionInfo)
	totalSize := int(collectionInfo.size)

	// Use parser to get clean separation
	separation, separationError := separate_collection_from_file(projectContext, collection)

	if separationError != nil {
		return -1, separationError
	}

	if !separation.hasMetadata {
		// No metadata header, return full file size
		return totalSize, no_error()
	}

	// Calculate metadata size
	metadataSize := len(separation.metadataHeader)

	// Return actual body size
	return totalSize - metadataSize, no_error()
}

// Calculates a SHA-256 checksum for .ostrichdb files based on body content only
@(require_results)
generate_checksum :: proc(projectContext:^lib.ProjectContext, collection: ^lib.Collection) -> (string, ^lib.Error) {
	using lib
	using fmt
	using strings

	// Use parser to get body content only for checksum
	bodyData, extractError := extract_body_only(projectContext, collection)
	// defer delete(bodyData)

	if extractError != nil {
		return get_err_msg(.COLLECTION_CANNOT_READ), extractError
	}

	// Hash the content
	//If the generate_checksum() proc is being called while creating a new collection the checksum should
	//have this initial value: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
	hashedData := hash.hash_string(hash.Algorithm.SHA256, bodyData)
	// defer delete(hashedData)

	//Format hash to be readable
	splitComma := split(tprintf("%x", hashedData), ",")
	joinedSplit := join(splitComma, "")
	trimRBracket := trim(joinedSplit, "]")
	trimLBRacket := trim(trimRBracket, "[")
	checksumString, _ := replace(trimLBRacket, " ", "", -1)
	// defer delete(checksumString)

	delete(splitComma)
	delete(joinedSplit)

	return clone(checksumString), no_error()
}


//Only used when to append the metadata template upon .ostrichdb file creation NOT modification
//Also sets the Collections time of creation
@(require_results)
append_metadata_header_to_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> ^lib.Error {
	using lib
	using strings

	collectionPath:= get_specific_collection_full_path(projectContext, collection)
	defer delete(collectionPath)

	data, readSuccess := read_file(collectionPath, get_caller_location())
	defer delete(data)
	if !readSuccess {
        return make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())
	}

	if has_prefix(string(data), METADATA_START) { //metadata header already found
		return make_new_err(.METADATA_HEADER_ALREADY_EXISTS, get_caller_location())
	}

	file, openSuccess := os.open(collectionPath, os.O_APPEND | os.O_WRONLY, FILE_MODE_RW_ALL)
	defer os.close(file)
	if openSuccess != 0{
        return make_new_err(.COLLECTION_CANNOT_OPEN, get_caller_location())
	}

	writeSuccess := write_to_file(collectionPath,transmute([]u8)concatenate(METADATA_HEADER),get_caller_location())
	if !writeSuccess {
     return  make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
	}

	return no_error()
}

// Sets the passed in metadata field with an explicit value that is defined within this procedure
// 0 = Encryption state, 1 = File Format Version, 2 = Permission, 3 = Date of Creation, 4 = Date Last Modified, 5 = File Size, 6 = Checksum
@(require_results)
explicitly_assign_metadata_value :: proc(projectContext: ^lib.ProjectContext, collection:^lib.Collection, field: lib.MetadataField, value: string = "") -> ^lib.Error {
	using lib
	using fmt
	using strings

    //Check to ensure the collection exists
    collectionExists, checkError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || checkError != nil{
        return  make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    // Use parser to get current metadata and body
    parsedCollection, parseError := parse_entire_collection(projectContext, collection)

    if parseError != nil {
        return parseError
    }

    metadata := parsedCollection.metadataHeader

	//not doing anything with h,m,s yet but its there if needed
	currentDate, h, m, s := get_date_and_time() // sets the files date of creation(FDOC) or file date last modified(FDLM)
	defer delete(currentDate)
	defer delete(h)
	defer delete(m)
	defer delete(s)

	// Update the specific field
	#partial switch field {
	case .ENCRYPTION_STATE:
        if value != "" {
            update_metadata_field(&metadata, field, value)
        } else {
            update_metadata_field(&metadata, field, "0") // Default to 0 if no value provided
        }
	case .FILE_FORMAT_VERSION:
        ffv, _:= get_ost_version()
        update_metadata_field(&metadata, field, string(ffv))
        // causes segfault??
        // delete(ffv)
	case .DATE_CREATION:
        update_metadata_field(&metadata, field, currentDate)
	case .DATE_MODIFIED:
        update_metadata_field(&metadata, field, currentDate)
	case .FILE_SIZE:
        actualSize, getSizeError := subtract_metadata_size_from_collection(projectContext, collection)
        if getSizeError != nil{
            return make_new_err(.METADATA_CANNOT_UPDATE_FIELD, get_caller_location())
        }
        if actualSize != -1 {
            sizeString := tprintf("%d Bytes", actualSize)
            update_metadata_field(&metadata, field, sizeString)
        }
	case .CHECKSUM:
        checksum, checksumError:=  generate_checksum(projectContext,collection)
        if checksumError != nil{
            return make_new_err(.METADATA_CANNOT_UPDATE_FIELD, get_caller_location())
        }
        update_metadata_field(&metadata, field, checksum)
	}

    // Reconstruct and write the collection
    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    updatedCollection := reconstruct_collection(metadata, parsedCollection.body.rawBody)

    writeSuccess := write_to_file(collectionPath, transmute([]byte)updatedCollection, get_caller_location())
    if !writeSuccess{
        return make_new_err(.COLLECTION_CANNOT_WRITE,get_caller_location())
    }

	return no_error()
}

//Returns the string value of the passed metadata field
@(require_results)
get_metadata_field_value :: proc(projectContext: ^lib.ProjectContext, collection:^lib.Collection, fieldName:string) -> (string, ^lib.Error) {
	using lib
	using fmt
    using strings

    // Use parser to get structured metadata
    metadata, parseError := parse_metadata_header_only(projectContext, collection)

    if parseError != nil {
        return get_err_msg(.METADATA_CANNOT_GET_FIELD_VALUE), parseError
    }

    // Return the requested field value
    switch fieldName {
    case "Encryption State":
        return clone(metadata.encryptionState), no_error()
    case "File Format Version":
        return clone(metadata.fileFormatVersion), no_error()
    case "Date of Creation":
        return clone(metadata.dateCreation), no_error()
    case "Date Last Modified":
        return clone(metadata.dateModified), no_error()
    case "File Size":
        return clone(metadata.fileSize), no_error()
    case "Checksum":
        return clone(metadata.checksum), no_error()
    }

	return get_err_msg(.METADATA_CANNOT_GET_FIELD_VALUE), make_new_err(.METADATA_CANNOT_GET_FIELD_VALUE, get_caller_location())
}

//Similar to the explicitly_assign_metadata_value but updates a fields value the passed in newValue
//Currently only supports the following metadata fields:
//ENCRYPTION STATE
//PERMSSION
@(require_results)
update_metadata_value :: proc(projectContext: ^lib.ProjectContext,collection:^lib.Collection, newValue: string,field: lib.MetadataField,colType: lib.CollectionType, username:..string) -> ^lib.Error{
	using lib
	using strings

    //Check to ensure the collection exists
    collectionExists, checkError:= check_if_collection_exists(projectContext,collection)
    if !collectionExists || checkError != nil{
        return  make_new_err(.COLLECTION_NOT_FOUND, get_caller_location())
    }

    // Use parser to get current state
    parsedCollection, parseError := parse_entire_collection(projectContext, collection)
    // defer free(&parsedCollection)

    if parseError != nil {
        return parseError
    }

    metadata := parsedCollection.metadataHeader

    // Update the specific field
    #partial switch field {
    case .ENCRYPTION_STATE:
        update_metadata_field(&metadata, field, newValue)
    case:
        return make_new_err(.METADATA_FIELD_NOT_FOUND, get_caller_location())
    }

    // Reconstruct and write the collection
    collectionPath := get_specific_collection_full_path(projectContext, collection)
    defer delete(collectionPath)

    updatedCollection := reconstruct_collection(metadata, parsedCollection.body.rawBody)

    writeSuccess := write_to_file(collectionPath, transmute([]byte)updatedCollection, get_caller_location())
    if !writeSuccess{
        return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
    }

    free_all()
	return no_error()
}

//Assigns all neccesary metadata field values after a collection has been made
@(require_results)
init_metadata_in_new_collection :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> ^lib.Error {
    using lib

    // Parse once
    parsedCollection, parseError := parse_entire_collection(projectContext, collection)

    if parseError != nil {
        return parseError
    }

    metadata := parsedCollection.metadataHeader

    currentDate, h, m, s := get_date_and_time()
    // defer delete(currentDate)
    // defer delete(h)
    // defer delete(m)
    // defer delete(s)

    // Update all fields in the same metadata struct
    update_metadata_field(&metadata, .ENCRYPTION_STATE, "0")

    ffv, _ := get_ost_version()
    update_metadata_field(&metadata, .FILE_FORMAT_VERSION, string(ffv))
    update_metadata_field(&metadata, .DATE_CREATION, currentDate)
    update_metadata_field(&metadata, .DATE_MODIFIED, currentDate)
    // CAUSES SEGFAULT?
    // delete(ffv)

    actualSize, getSizeError := subtract_metadata_size_from_collection(projectContext, collection)
    if getSizeError == nil {
        sizeString := fmt.tprintf("%d Bytes", actualSize)
        update_metadata_field(&metadata, .FILE_SIZE, sizeString)
    }

    checksum, checksumError := generate_checksum(projectContext, collection)
    if checksumError == nil {
        // defer delete(checksum)
        update_metadata_field(&metadata, .CHECKSUM, checksum)
    }

    // Write once at the end
    collectionPath := get_specific_collection_full_path(projectContext, collection)
    // defer delete(collectionPath)

    updatedCollection := reconstruct_collection(metadata, parsedCollection.body.rawBody)

    writeSuccess := write_to_file(collectionPath, transmute([]byte)updatedCollection, get_caller_location())
    if !writeSuccess {
        return make_new_err(.COLLECTION_CANNOT_WRITE, get_caller_location())
    }

    return no_error()
}

//Used after most operations on a collection file to update metadata fields that need to be updated
@(require_results)
update_metadata_fields_after_operation :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection) -> ^lib.Error {
    using lib

    updateCount := 0

	resultOne:= explicitly_assign_metadata_value(projectContext, collection, .DATE_MODIFIED)
	if resultOne == nil {updateCount +=1}

	resultTwo:= explicitly_assign_metadata_value(projectContext, collection, .FILE_FORMAT_VERSION)
	if resultTwo == nil {updateCount +=1}

	resultThree:=explicitly_assign_metadata_value(projectContext, collection, .FILE_SIZE)
	if resultThree == nil {updateCount +=1}

	resultFour:=explicitly_assign_metadata_value(projectContext, collection, .CHECKSUM)
	if resultFour == nil {updateCount +=1}

	if updateCount == 4 {
	    return no_error()
	}

	return make_new_err(.METADATA_CANNOT_UPDATE_FIELDS_AFTER_OPERATION, get_caller_location())
}
