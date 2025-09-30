package library

import "core:time"
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
FILE_MODE_RW_ALL :: 0o666
FILE_MODE_EXECUTABLE :: 0o755
FILE_MODE_PRIVATE ::0o700

RED :: "\033[31m"
BOLD :: "\033[1m"
RESET :: "\033[0m"

TAB_NEW_R_BRACE := "\t\n},"
R_BRACE_COMMA   := "\n},\n"
NEWLINE         := "\n"

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

LOG_DIR_PATH :: "./logs/"
RUNTIME_LOG_PATH :: "./logs/runtime.log"
ERROR_LOG_PATH :: "./logs/errors.log"
SERVER_LOG_PATH :: "./logs/server_events.log"
OST_EXT :: ".ostrichdb"

MAX_DATA_STRUCURE_NAME_LEN :: 32

TIME_COMPONENT_LENGTH :: 2
MAX_HOURS :: 23
MAX_MINUTES :: 59
MAX_SECONDS :: 59

DISALLOWED_CHARS_PATTERN :: `[^a-zA-Z0-9]`

ServerPorts:[]int:{8042,8044,8046,8048,8050}

MINUTE_IN_SECONDS :: 60.0
HOUR_IN_SECONDS :: 3600.0