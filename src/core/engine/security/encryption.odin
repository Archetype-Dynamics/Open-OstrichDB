package security

import "core:os"
import "core:fmt"
import "core:crypto/"
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

	// collectionPath := get_specific_collection_full_path(projectContext, collection)
	// defer delete(collectionPath)

	// //Update the encryption state metadaheader member to 1 before reading bytes
	// assignMetadataValueSuccess:= explicitly_assign_metadata_value(projectContext, collection, MetadataField.ENCRYPTION_STATE, "1")
	// if assignMetadataValueSuccess != nil do return nil, make_new_err(.METADATA_CANNOT_UPDATE_FIELD, get_caller_location())


	// data, readSuccess := read_file(collectionPath, get_caller_location())
	// defer delete(data)
	// if !readSuccess do return nil, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())

	// dataSize := len(data)

	// aad: []u8 = nil
	// dst := make([]u8, dataSize + aes.GCM_IV_SIZE + aes.GCM_TAG_SIZE) //create a buffer that is the size of the data plus 16 bytes for the iv and 16 bytes for the tag
	// iv := dst[:aes.GCM_IV_SIZE] //set the iv to the first 16 bytes of the buffer
	// encryptedData := dst[aes.GCM_IV_SIZE:][:dataSize] //set the actual encrypted data to the bytes after the iv
	// tag := dst[aes.GCM_IV_SIZE + dataSize:] //set the tag to the 16 bytes at the end of the buffer

	// crypto.rand_bytes(iv) //generate a random iv

	// gcmContext: aes.Context_GCM //create a gcm context
	// aes.init_gcm(&gcmContext, key) //initialize the gcm context with the key

	// aes.seal_gcm(&gcmContext, encryptedData, tag, iv, aad, data) //encrypt the data

	// writeSuccess := write_to_file(collectionPath, dst, get_caller_location()) //write the encrypted data to the file
	// if writeSuccess {
	//     return  dst, no_error()
	// }
	// 	//If we fail to write the encrypted data to the file, reset the encrypted state metadata back to 0
	// 	setEncState:= explicitly_assign_metadata_value(projectContext, collection, MetadataField.ENCRYPTION_STATE)
	// 	if setEncState != nil {
	// 	    return nil, make_new_err(.METADATA_CANNOT_UPDATE_FIELD, get_caller_location())
	// 	}

	// 	return nil, make_new_err(.SECURITY_CANNOT_ENCRYPT_COLLECTION, get_caller_location())
		return nil, nil
}

//Uses the users Kinde Auth info to encrypt collections
@(require_results)
encrypt_collection_with_user_context :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (encData: []u8, err: ^lib.Error) {
    using lib
    using data
    using fmt

    // if projectContext == nil || len(projectContext.userID) == 0 {
    //     return nil, make_new_err(.SECURITY_INVALID_CONTEXT, get_caller_location())
    // }

    // masterKey, keyErr := get_user_master_key(projectContext.userID)
    // if keyErr != nil {
    //     return nil, keyErr
    // }
    // defer clear_key_from_memory(masterKey)

    // encryptedData, encErr := encrypt_collection(projectContext, collection, masterKey)
    // if encErr != nil {
    //     return nil, encErr
    // }

    // return encryptedData, no_error()
    return nil, nil
}