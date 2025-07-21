package library

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:strings"
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

//Constants for text colors and styles
RED :: "\033[31m"
BLUE :: "\033[34m"
GREEN :: "\033[32m"
YELLOW :: "\033[33m"
ORANGE :: "\033[38;5;208m"

BOLD :: "\033[1m"
ITALIC :: "\033[3m"
UNDERLINE :: "\033[4m"
BOLD_UNDERLINE :: "\033[4m\033[1m"
RESET :: "\033[0m"

//TODO: add a bool return to ensure the version is loaded???
get_ost_version :: proc() -> []u8 {
	data := #load("../../version")
	return data
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

show_server_kill_msg :: proc() {
	fmt.printfln(
		"Enter %s'kill'%s or %s'exit'%s to stop the server\n",
		BOLD_UNDERLINE,
		RESET,
		BOLD_UNDERLINE,
		RESET,
	)
}
