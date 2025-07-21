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

 //    collectionPath := get_specific_collection_full_path(projectContext, collection)
 //    defer delete(collectionPath)

	// ciphertext, readSuccess := read_file(collectionPath, get_caller_location())
	// defer delete(ciphertext)
	// if !readSuccess do return nil, make_new_err(.COLLECTION_CANNOT_READ, get_caller_location())

	// dataSize := len(ciphertext) - aes.GCM_IV_SIZE - aes.GCM_TAG_SIZE // the size of the ciphertext minus 16 bytes for the iv then minus another 16 bytes for the tag
	// if dataSize <= 0 do return nil, make_new_err(.SECURITY_CANNOT_DECRYPT_COLLECTION, get_caller_location()) //if n is less than or equal to 0 then return nil

	// aad: []u8 = nil
	// decryptedData := make([]u8, dataSize) //allocate the size of the decrypted data that comes from the allocation context
	// iv := ciphertext[:aes.GCM_IV_SIZE] //iv is the first 16 bytes
	// encryptedData := ciphertext[aes.GCM_IV_SIZE:][:dataSize] //the actual encryptedData is the bytes after the iv
	// tag := ciphertext[aes.GCM_IV_SIZE + dataSize:] // tag is the 16 bytes at the end of the ciphertext

	// gcmContext: aes.Context_GCM
	// aes.init_gcm(&gcmContext, key) //initialize the gcm context with the key

	// if !aes.open_gcm(&gcmContext, decryptedData, iv, aad, encryptedData, tag) {
	// 	delete(decryptedData)
	// 	delete (encryptedData)
	// 	return nil, make_new_err(.SECURITY_CANNOT_DECRYPT_COLLECTION, get_caller_location())
	// }

	// aes.reset_gcm(&gcmContext)

	// os.remove(collectionPath)
	// writeSuccess := write_to_file(collectionPath, decryptedData, get_caller_location())
 //    if writeSuccess {
 //        return decryptedData, no_error()
 //    }

	// return nil, make_new_err(.SECURITY_CANNOT_DECRYPT_COLLECTION, get_caller_location())
	return nil, nil
}

//Uses the users Kinde Auth info to decrypt collections
decrypt_collection_with_user_context :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection) -> (decData: []u8, err: ^lib.Error) {
    using lib
    using data

    // masterKey, keyErr := get_user_master_key(projectContext.userID)
    // if keyErr != nil {
    //     return nil, keyErr
    // }
    // defer clear_key_from_memory(masterKey)

    // return decrypt_collection(projectContext, collection, masterKey)
    return nil, nil
}