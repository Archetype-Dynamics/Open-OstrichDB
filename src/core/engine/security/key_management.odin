package security

import "core:os"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:crypto"
import "core:crypto/hash"
import "core:encoding/hex"
import "../data"
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
            Contains logic for ser-specific master key management
*********************************************************/

KEY_DERIVATION_ITERATIONS :: 100_000  // PBKDF2 iterations
SALT_SIZE :: 32                        // 256-bit salt
KEY_SIZE :: 32                         // 256-bit key for AES-256

// Get or create user salt
@(require_results)
get_or_create_user_salt :: proc(userID: string) -> ([]byte, ^lib.Error) {
    using lib
    using config
    using fmt

    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    // Build path to user's salt file
    saltPath := fmt.tprintf("%s%s/system/security/salt.key",currentOstrichPathConfig.projectBasePath, userID)


    // Check if salt already exists
    if saltData, ok := os.read_entire_file(saltPath); ok {
        return saltData, no_error()
    }
    salt := generate_user_salt()

    //Check that correct dir  structure exists
    userSystemDir := fmt.tprintf("%s%s/system/",
        currentOstrichPathConfig.projectBasePath, userID)
    securityDir := fmt.tprintf("%s%s/system/security/",
        currentOstrichPathConfig.projectBasePath, userID)

    os.make_directory(userSystemDir, FILE_MODE_EXECUTABLE)
    os.make_directory(securityDir, FILE_MODE_PRIVATE)

    // Store the users salt
    storeErr := store_user_salt(userID, salt)
    if storeErr != nil {
        delete(salt)
        return nil, storeErr
    }

    return salt, no_error()
}

//Used to generate random salt
@(require_results)
generate_user_salt :: proc() -> []byte {
    salt := make([]byte, SALT_SIZE)
    crypto.rand_bytes(salt)
    return salt
}

//This proc stores the users salt to the appropriate {userID}/security/salt.key file
@(require_results)
store_user_salt :: proc(userID: string, salt: []byte) -> ^lib.Error {
    using lib
    using config

    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    saltPath := fmt.tprintf("%s%s/system/security/salt.key",
        currentOstrichPathConfig.projectBasePath, userID)
    defer delete(saltPath)

    if !os.write_entire_file(saltPath, salt) {
        return make_new_err(.SECURITY_CANNOT_STORE_SALT, get_caller_location())
    }

    return no_error()
}

//Finds the users stored salt key on disk, and loads it into mem
@(require_results)
load_user_salt :: proc(userID: string) -> ([]byte, ^lib.Error) {
    using lib
    using config

    if currentOstrichPathConfig == nil {
        currentOstrichPathConfig = init_dynamic_paths()
    }

    saltPath := fmt.tprintf("%s%s/system/security/salt.key",currentOstrichPathConfig.projectBasePath, userID)

    saltData, ok := os.read_entire_file(saltPath)
    if !ok {
        return nil, make_new_err(.SECURITY_SALT_NOT_FOUND, get_caller_location())
    }

    return saltData, no_error()
}

// Derive user master key using PBKDF2
// See: https://en.wikipedia.org/wiki/PBKDF2 for more info. I dont understand the shit but hey it works
@(require_results)
derive_user_master_key :: proc(userID: string, salt: []byte) -> ([]byte, ^lib.Error) {
    using lib
    using fmt

    // Get server secret from environment
    serverSecret := os.get_env("OSTRICH_MASTER_SECRET")
    defer delete(serverSecret)
    if len(serverSecret) == 0 {
        return nil, make_new_err(.SECURITY_NO_SERVER_SECRET, get_caller_location())
    }

    // Combine inputs: UserID + ServerSecret
    combined := fmt.tprintf("%s:%s", userID, serverSecret)

    // Derive key using PBKDF2 with SHA-256
    derivedKey := make([]byte, KEY_SIZE)

    success := derive_key_pbkdf2(
        transmute([]byte)combined,
        salt,
        KEY_DERIVATION_ITERATIONS,
        derivedKey
    )

    if !success {
        delete(derivedKey)
        return nil, make_new_err(.SECURITY_KEY_DERIVATION_FAILED, get_caller_location())
    }

    return derivedKey, no_error()
}

@(private)
derive_key_pbkdf2 :: proc(password: []byte, salt: []byte, iterations: int, output: []byte) -> bool {
    using hash

    if len(output) != KEY_SIZE {
        return false
    }

    // This is a simplified version - proper PBKDF2 would use HMAC
    combined := make([]byte, len(password) + len(salt))
    defer delete(combined)

    copy(combined[:len(password)], password)
    copy(combined[len(password):], salt)

    // Initial hash
    current := hash_bytes_to_buffer(Algorithm.SHA256, combined, output)

    // Iterate
    for i in 1..<iterations {
        current = hash_bytes_to_buffer(Algorithm.SHA256, output[:KEY_SIZE], output)
    }

    return true
}


clear_key_from_memory :: proc(key: []byte) {
    if key != nil {
        mem.set(raw_data(key), 0, len(key))
        delete(key)
    }
}

//Get a users master key
@(require_results)
get_user_master_key :: proc(userID: string) -> ([]byte, ^lib.Error) {
    using lib

    //Need to create salt
    salt, saltErr := get_or_create_user_salt(userID)
    if saltErr != nil {
        return nil, saltErr
    }
    defer delete(salt)

    // Derive master key
    masterKey, keyErr := derive_user_master_key(userID, salt)
    if keyErr != nil {
        return nil, keyErr
    }

    return masterKey, no_error()
}

@(require_results)
execute_encrypted_operation :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection,operation: proc(^lib.ProjectContext, ^lib.Collection) -> ^lib.Error) -> ^lib.Error {
    using lib

    //First check the encryption state
    encryptionState, stateErr := data.get_metadata_field_value(projectContext, collection, "Encryption State")
    if stateErr != nil {
        return stateErr
    }
    defer delete(encryptionState)

    isEncrypted := encryptionState == "1"

    //decrypt if the collection needs to be
    if isEncrypted {
        _, decryptErr := decrypt_collection_with_user_context(projectContext, collection)
        if decryptErr != nil {
            return decryptErr
        }
    }

    //Perform the passed in operation
    operationError := operation(projectContext, collection)

    // Re-encrypt if the collection was decrypted
    if isEncrypted {
        _, encryptErr := encrypt_collection_with_user_context(projectContext, collection)
        if encryptErr != nil {
            // This is critical - operation succeeded but re-encryption failed
            return make_new_err(.SECURITY_CRITICAL_REENCRYPTION_FAILED, get_caller_location())
        }
    }

    return operationError
}