package library

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:strings"
import C"core:c/libc"
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
            collections within the OstrichDB engine.
*********************************************************/

ostrich_art := `
$$$$$$\              $$\               $$\           $$\       $$$$$$$\  $$$$$$$\
$$  __$$\             $$ |              \__|          $$ |      $$  __$$\ $$  __$$\
$$ /  $$ | $$$$$$$\ $$$$$$\    $$$$$$\  $$\  $$$$$$$\ $$$$$$$\  $$ |  $$ |$$ |  $$ |
$$ |  $$ |$$  _____|\_$$  _|  $$  __$$\ $$ |$$  _____|$$  __$$\ $$ |  $$ |$$$$$$$\ |
$$ |  $$ |\$$$$$$\    $$ |    $$ |  \__|$$ |$$ /      $$ |  $$ |$$ |  $$ |$$  __$$\
$$ |  $$ | \____$$\   $$ |$$\ $$ |      $$ |$$ |      $$ |  $$ |$$ |  $$ |$$ |  $$ |
 $$$$$$  |$$$$$$$  |  \$$$$  |$$ |      $$ |\$$$$$$$\ $$ |  $$ |$$$$$$$  |$$$$$$$  |
 \______/ \_______/    \____/ \__|      \__| \_______|\__|  \__|\_______/ \_______/
==================================================================================
 %s: %s%s%s
==================================================================================`


get_ost_version :: proc() -> ([]u8, bool) {
    loaded := false
	data := #load("../../version")
	if len(data) > 0{
	    loaded = true
	}
	return data, loaded
}

get_file_info :: proc(file: string) -> os.File_Info {
	info, _ := os.stat(file)
	return info
}

rename_file :: proc(old_path, new_path: string) -> bool {
    when ODIN_OS == .Darwin {
        return os.rename(old_path, new_path)
    } else {
        return os.rename(old_path, new_path) == os.ERROR_NONE
    }
    return false
}

remove_file :: proc(path: string) -> bool {
    when ODIN_OS == .Darwin {
        return os.remove(path) == os.ERROR_NONE
    } else {
        return os.remove(path) == os.ERROR_NONE
    }
    return false
}

remove_dir :: proc(path: string) -> bool {
    when ODIN_OS == .Darwin {
        return os.remove(path) == .NONE
    } else {
        return os.remove_directory(path) == os.ERROR_NONE
    }
    return false
}
