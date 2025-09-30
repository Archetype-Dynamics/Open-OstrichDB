package security

import "core:os"
import "core:fmt"
import "core:strings"
import "core:math/rand"
import "core:crypto/aes"
import "core:crypto/aead"
import "core:encoding/hex"
import "../data"
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
            Logic for collection decryption
*********************************************************/

/*
Note: Here is a general outline of the "EDE" process within OstrichDB:

Encryption rocess :
1. Generate IV (16 bytes)
2. Create ciphertext buffer (same size as input data)
3. Create tag buffer (16 bytes for GCM)
4. Encrypt the data into ciphertext buffer
5. Combine IV + ciphertext for storage

In plaintest the encrypted data would look like:
[IV (16 bytes)][Ciphertext (N bytes)]
Where N is the size of the plaintext data
----------------------------------------

Decryption process :
1. Read IV from encrypted data
2. Read ciphertext from encrypted data
3. Use IV, ciphertext, and tag to decrypt data
*/

//Expects the passed in collection to be encrypted. Decrypts then returns data and success
decrypt_collection :: proc(projectContext:^lib.ProjectContext,collection: ^lib.Collection,  key: []u8) -> (decData: []u8, err: ^lib.Error) {
    using lib
    using data
    using fmt

	// First read the raw file to see its actual size
	collectionPath := get_specific_collection_full_path(projectContext, collection)
	defer delete(collectionPath)
	rawFileData, rawReadSuccess := read_file(collectionPath, get_caller_location())
	if rawReadSuccess {
		defer delete(rawFileData)
	} else {
		return []u8{}, make_new_err(.STANDARD_CANNOT_READ_FILE, get_caller_location())
	}

	// Parse collection to separate metadata and body
	parsedCollection, parseError := parse_entire_collection(projectContext, collection)
	if parseError != nil {
		return nil, parseError
	}

	// Extract encrypted body content
	encryptedBody := transmute([]u8)parsedCollection.body.rawBody
	if len(encryptedBody) == 0 { //if empty nothing to decryt
		return nil, no_error()
	}

	// Decrypt body content
	dataSize := len(encryptedBody) - aes.GCM_IV_SIZE - aes.GCM_TAG_SIZE
	if dataSize <= 0 {
		return nil, make_new_err(.SECURITY_CANNOT_DECRYPT_COLLECTION, get_caller_location())
	}

	aad: []u8 = nil
	decryptedData := make([]u8, dataSize)
	iv := encryptedBody[:aes.GCM_IV_SIZE] // First 16 bytes
	ciphertext := encryptedBody[aes.GCM_IV_SIZE:][:dataSize] // Encrypted data after IV
	tag := encryptedBody[aes.GCM_IV_SIZE + dataSize:] // Tag at the end

	gcmContext: aes.Context_GCM
	aes.init_gcm(&gcmContext, key)

	if !aes.open_gcm(&gcmContext, decryptedData, iv, aad, ciphertext, tag) {
		delete(decryptedData)
		return nil, make_new_err(.SECURITY_CANNOT_DECRYPT_COLLECTION, get_caller_location())
	}

	aes.reset_gcm(&gcmContext)

	// Update metadata encryption state
	metadata := parsedCollection.metadataHeader
	update_metadata_field(&metadata, .ENCRYPTION_STATE, "0")

	// Reconstruct collection with plaintext metadata + decrypted body
	reconstructedCollection := reconstruct_collection(metadata, string(decryptedData))

	// Write back to file
	cPath := get_specific_collection_full_path(projectContext, collection)
	defer delete(cPath)
	writeSuccess := write_to_file(cPath, transmute([]u8)reconstructedCollection, get_caller_location())
	if !writeSuccess {
		delete(decryptedData)
		return nil, make_new_err(.SECURITY_CANNOT_DECRYPT_COLLECTION, get_caller_location())
	}

	return decryptedData, no_error()
}

//Uses the users Kinde Auth info to decrypt collections
decrypt_collection_with_user_context :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (decData: []u8, err: ^lib.Error) {
    using lib
    using data

    if projectContext == nil || len(projectContext.userID) == 0 {
        return nil, make_new_err(.SECURITY_INVALID_CONTEXT, get_caller_location())
    }

    masterKey, keyErr := get_user_master_key(projectContext.userID)
    if keyErr != nil {
        return nil, keyErr
    }
    defer clear_key_from_memory(masterKey)

    return decrypt_collection(projectContext, collection, masterKey)
}