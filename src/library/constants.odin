package library

import "core:time"
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

METADATA_START :: "@@@@@@@@@@@@@@@TOP@@@@@@@@@@@@@@@\n"
METADATA_END :: "@@@@@@@@@@@@@@@BTM@@@@@@@@@@@@@@@\n"

METADATA_HEADER: []string : {
	METADATA_START,
	"# Encryption State: %es\n",
	"# File Format Version: %ffv\n",
	"# Permission: %perm\n", //Read-Only/Read-Write/Inaccessible
	"# Date of Creation: %fdoc\n",
	"# Date Last Modified: %fdlm\n",
	"# File Size: %fs Bytes\n",
	"# Checksum: %cs\n",
	METADATA_END,
	"\n"
}

SYS_MASTER_KEY := []byte {
	0x8F,
	0x2A,
	0x1D,
	0x5E,
	0x9C,
	0x4B,
	0x7F,
	0x3A,
	0x6D,
	0x0E,
	0x8B,
	0x2C,
	0x5F,
	0x9A,
	0x7D,
	0x4E,
	0x1B,
	0x3C,
	0x6A,
	0x8D,
	0x2E,
	0x5F,
	0x7C,
	0x9B,
	0x4A,
	0x1D,
	0x8E,
	0x3F,
	0x6C,
	0x9B,
	0x2A,
	0x5,
}


//SERVER DYNAMIC ROUTE CONSTANTS
BATCH_C_DYNAMIC_BASE :: "batch/c/*"
BATCH_CL_DYNAMIC_BASE::"batch/c/*/cl/*"
BATCH_R_DYNAMIC_BASE::"batch/c/*/cl/*/r/*"

//SERVER DYNAMIC ROUTE CONSTANTS
C_DYNAMIC_BASE :: "/c/*"
CL_DYNAMIC_BASE :: "/c/*/cl/*"
R_DYNAMIC_BASE :: "/c/*/cl/*/r/*"
R_DYNAMIC_TYPE_QUERY :: "/c/*/cl/*/r/*?type=*" //Only used for creating a new record without a value...POST request
R_DYNAMIC_TYPE_VALUE_QUERY :: "/c/*/cl/*/r/*?type=*&value=*" //Used for setting an already existing records value...PUT request


LOG_DIR_PATH :: "./logs/"
RUNTIME_LOG_PATH :: "./logs/runtime.log"
ERROR_LOG_PATH :: "./logs/errors.log"
SERVER_LOG_PATH :: "./logs/server_events.log"

//Non-changing PATH CONSTANTS
FFVF_PATH :: "ost_file_format_version.tmp"
OST_EXT :: ".ostrichdb"

MAX_COLLECTION_NAME_LENGTH :: 64

ServerPorts:[]int:{8042,8044,8046,8048,8050}