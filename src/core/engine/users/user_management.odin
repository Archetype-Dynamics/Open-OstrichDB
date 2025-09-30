package users

import  "core:fmt"
import lib"../../../library"
import C"core:c/libc"
import "core:os"
/********************************************************
Author: Marshall Burns
GitHub: @SchoolyB
Contributors:

Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
All Rights Reserved.

This software is proprietary and confidential. Unauthorized copying,
distribution, modification, or use of this software, in whole or in part,
is strictly prohibited without the express written permission of
Archetype Dynamics, Inc.


File Description:
            Contains logic for managing user accounts
*********************************************************/

make_new_user :: proc(id:="", email:="") -> ^lib.User {
    using lib

    user := new(User)
    user.id = id
    user.email = email

    return user
}


//User account DELETION related PROCS
//remove all the shit in the users dir before deleting the parent dir itself
delete_users_sub_dirs_and_files :: proc(path: string) -> bool {
    using lib

    userPath, _:= os.open(path)
    entries, err := os.read_dir(userPath, -1)
    if err != nil {
        return false
    }
    defer delete(entries)

    for entry in entries {
        fullPath := fmt.tprintf("%s/%s", path, entry.name)

        if entry.is_dir {
            if !delete_users_sub_dirs_and_files(fullPath) {
                return false
            }
        } else {
            if os.remove(fullPath) != nil {
                return false
            }
        }
    }

    if os.remove(path) != nil {
        return false
    }

    return true
}

delete_user_account :: proc(user: ^lib.User) -> ^lib.Error {
    using lib

    if !delete_users_sub_dirs_and_files(user.id){
        free_all()
        return make_new_err(.CANNOT_DELETE_USER, get_caller_location())
    }

    free_all()
    return no_error()
}

