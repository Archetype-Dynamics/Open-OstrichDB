package security

import "core:os"
import "core:fmt"
import "core:crypto"
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
            Logic for collection encryption
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

encrypt_collection :: proc(projectContext: ^lib.ProjectContext,collection :^lib.Collection, key: []u8) -> (encData: []u8, err:^lib.Error) {
    using lib
    using data
    using fmt

	// Parse collection to separate metadata and body
	parsedCollection, parseError := parse_entire_collection(projectContext, collection)
	if parseError != nil {
		return nil, parseError
	}

	// Extract body content only
	bodyContent := parsedCollection.body.rawBody

	// Always update metadata encryption state to 1, even for empty bodies
	metadata := parsedCollection.metadataHeader
	update_metadata_field(&metadata, .ENCRYPTION_STATE, "1")

	if len(bodyContent) == 0 {
		// Even with empty body, we need to reconstruct and write with encryption state = 1
		reconstructedCollection := reconstruct_collection(metadata, bodyContent)
		collectionPath := get_specific_collection_full_path(projectContext, collection)
		defer delete(collectionPath)
		writeSuccess := write_to_file(collectionPath, transmute([]u8)reconstructedCollection, get_caller_location())
		if !writeSuccess {
			return nil, make_new_err(.SECURITY_CANNOT_ENCRYPT_COLLECTION, get_caller_location())
		}
		return nil, no_error()
	}

	// Encrypt body content using AES-GCM
	bodyBytes := transmute([]u8)bodyContent
	dataSize := len(bodyBytes)
	aad: []u8 = nil
	dst := make([]u8, dataSize + aes.GCM_IV_SIZE + aes.GCM_TAG_SIZE) // IV + encrypted data + tag
	iv := dst[:aes.GCM_IV_SIZE] // First N bytes for IV
	encryptedData := dst[aes.GCM_IV_SIZE:][:dataSize] // Encrypted data after IV
	tag := dst[aes.GCM_IV_SIZE + dataSize:] // Tag at the end

	crypto.rand_bytes(iv) // Generate random IV
	gcmContext: aes.Context_GCM
	aes.init_gcm(&gcmContext, key)
	aes.seal_gcm(&gcmContext, encryptedData, tag, iv, aad, bodyBytes)

	// Reconstruct collection with plaintext metadata + encrypted body
	reconstructedCollection := reconstruct_collection(metadata, string(dst))

	collectionPath := get_specific_collection_full_path(projectContext, collection)
	defer delete(collectionPath)
	writeSuccess := write_to_file(collectionPath, transmute([]u8)reconstructedCollection, get_caller_location())
	if !writeSuccess {
		delete(dst)
		return nil, make_new_err(.SECURITY_CANNOT_ENCRYPT_COLLECTION, get_caller_location())
	}

	// Verify what was actually written
	writtenData, readSuccess := read_file(collectionPath, get_caller_location())
	if readSuccess {
		defer delete(writtenData)
	} else {
		return []u8{}, make_new_err(.STANDARD_CANNOT_WRITE_TO_FILE, get_caller_location())
	}

	return dst, no_error()
}

//Uses the users Kinde Auth info to encrypt collections
@(require_results)
encrypt_collection_with_user_context :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (encData: []u8, err: ^lib.Error) {
    using lib
    using data
    using fmt

    if projectContext == nil || len(projectContext.userID) == 0 {
        return nil, make_new_err(.SECURITY_INVALID_CONTEXT, get_caller_location())
    }

    masterKey, keyErr := get_user_master_key(projectContext.userID)
    if keyErr != nil {
        return nil, keyErr
    }
    defer clear_key_from_memory(masterKey)

    encryptedData, encErr := encrypt_collection(projectContext, collection, masterKey)
    if encErr != nil {
        return nil, encErr
    }

    return encryptedData, no_error()
}