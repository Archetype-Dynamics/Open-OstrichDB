package config

import "core:fmt"
import "core:os"
import "core:strings"
import lib"../../library"
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
            Simple .env file parser for development convenience
            Only loads .env in development environment
*********************************************************/

// Load environment variables from .env file
load_dotenv :: proc(filePath: string = ".env") -> bool {
    using fmt
    using strings

    // Only load .env in development to avoid production issues
    if get_environment() != "development" {
        return true // Don't load .env in production
    }

    data, ok := os.read_entire_file(filePath)
    if !ok {
        // .env file not found - that's okay for development
        return true
    }
    defer delete(data)

    content := string(data)
    lines := split_lines(content)
    defer delete(lines)

    for line in lines {
        line := trim_space(line)

        // Skip empty lines and comments
        if len(line) == 0 || has_prefix(line, "#") {
            continue
        }

        // Parse KEY=VALUE format
        if eq_pos := index(line, "="); eq_pos != -1 {
            key := trim_space(line[:eq_pos])
            value := trim_space(line[eq_pos + 1:])

            // Remove quotes if present
            if len(value) >= 2 {
                if (has_prefix(value, "\"") && has_suffix(value, "\"")) ||
                   (has_prefix(value, "'") && has_suffix(value, "'")) {
                    value = value[1:len(value)-1]
                }
            }

            // Set environment variable if not already set
            if os.get_env(key) == "" {
                os.set_env(key, value)
            }
        }
    }

    return true
}

@(require_results)
load_config_with_dotenv :: proc(environment: string = "") -> ^lib.AppConfig {
    using fmt

    // Load .env file first (only in development)
    load_dotenv()

    // Then proceed with normal config loading
    return load_config(environment)
}


validate_security_config :: proc() -> bool {
    serverSecret := os.get_env("OSTRICH_MASTER_SECRET")
    defer delete(serverSecret)

    if len(serverSecret) < 32 {
        fmt.println("ERROR: OSTRICH_MASTER_SECRET must be at least 32 characters long")
        return false
    }

    return true
}