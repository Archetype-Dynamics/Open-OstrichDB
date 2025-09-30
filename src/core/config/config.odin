package config

import "core:fmt"
import "core:os"
import "core:strings"
import "core:encoding/json"
import lib "../../library"
import "core:strconv"
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
            Configuration management system for OstrichDB server.
            Supports environment-based configs and environment variable overrides.
*********************************************************/


// Global config instance
@(private)
currentConfig: ^lib.AppConfig

// Get the current environment from environment variable or default to development
@(require_results)
get_environment :: proc() -> string {
    env := os.get_env("OSTRICH_ENV")

    if env == "" do return "development" //If the custom .env  isnt loaded correctly the just set development

    // Normalize environment names - only allow development and production
    envLower := strings.to_lower(env)
    switch envLower {
    case "prod", "production":
        return "production"
    case "dev", "development":
        return "development"
    case:
        fmt.printf("WARNING: Unknown environment '%s', defaulting to development\n", env)
        return "development"
    }
}

// Get default configuration values
@(require_results)
get_default_config :: proc() -> lib.AppConfig {
    using lib

    return AppConfig{
        server = ServerConfig{
            port = 8042,
            host = "localhost",
            bindAddress = "0.0.0.0",
            maxConnections = 100,
            requestTimeoutSeconds = 30,
            backlogSize = 5,
        },
        database = DatabaseConfig{
            storagePath = "./data",
            maxFileSizeMb = 100,
            backupEnabled = true,
            backupIntervalHours = 24,
        },
        logging = LoggingConfig{
            level = "INFO",
            filePath = "./logs/ostrich.log",
            consoleOutput = true,
            maxFileSizeMb = 50,
            rotateFiles = true,
            maxRotatedFiles = 5,
        },
        cors = CorsConfig{
            allowedOrigins = []string{"http://localhost:3000", "http://localhost:8080", "http://localhost:5173", "https://ostrichdb.com", "https://www.ostrichdb.com"}, //Possible client origins not the servers port :)
            allowedMethods =[]HttpMethod{.GET, .POST, .PUT, .DELETE, .HEAD, .OPTIONS},
            allowedHeaders = []string{"Content-Type", "Authorization", "X-Requested-With"},
            exposeHeaders = []string{},
            maxAgeSeconds = 86400,
            allowCredentials = false,
        },
        security = SecurityConfig{
            rateLimitRequestsPerMinute = 60,
            maxRequestBodySizeMb = 10,
            enableAuth = false,
        },
    }
}

//Load the a config.json file of the passed in name if no name is given default
@(require_results)
load_config :: proc(environment: string = "") -> ^lib.AppConfig {
    using fmt

    env := environment if environment != "" else get_environment()

    // Start with default config
    config := get_default_config()

    // Try to load from config file
    configFilePath := tprintf("./config/%s.json", env)

    if configData, ok := os.read_entire_file(configFilePath); ok {
        defer delete(configData)

        if json_err := json.unmarshal(configData, &config); json_err != nil {
            printf("WARNING: Failed to parse config file %s: %v\n", configFilePath, json_err)
            printf("Using default configuration with environment overrides\n")
        }
    } else {
        printf("Config file not found: %s\n", configFilePath)
        printf("Using default configuration with environment overrides\n")
    }

    // Apply environment variable overrides
    apply_env_overrides(&config)

    // Validate the configuration
    if validation_err := validate_config(&config); validation_err != "" {
        printf("ERROR: Configuration validation failed: %v\n", validation_err)
        os.exit(1)
    }

    // Store globally and return
    currentConfig = new(lib.AppConfig)
    currentConfig^ = config

    return currentConfig
}

// Apply environment variable overrides to configuration
apply_env_overrides :: proc(config: ^lib.AppConfig) {

    // Server overrides
    if port_str := os.get_env("OSTRICH_SERVER_PORT"); port_str != "" {
        if port, ok := strconv.parse_int(port_str); ok {
            config.server.port = port
        }
    }

    if host := os.get_env("OSTRICH_SERVER_HOST"); host != "" {
        config.server.host = host
    }

    if bindAddress := os.get_env("OSTRICH_SERVER_BIND_ADDRESS"); bindAddress != "" {
        config.server.bindAddress = bindAddress
    }

    // Database overrides
    if storagePath := os.get_env("OSTRICH_DATABASE_STORAGE_PATH"); storagePath != "" {
        config.database.storagePath = storagePath
    }

    if backUpsEnabled := os.get_env("OSTRICH_DATABASE_BACKUP_ENABLED"); backUpsEnabled != "" {
        config.database.backupEnabled = backUpsEnabled == "true" || backUpsEnabled == "1"
    }

    // Logging overrides
    if logLevel := os.get_env("OSTRICH_LOG_LEVEL"); logLevel != "" {
        config.logging.level = strings.to_upper(logLevel)
    }

    if logPath := os.get_env("OSTRICH_LOG_FILE_PATH"); logPath != "" {
        config.logging.filePath = logPath
    }

    if consolOutputEnabled := os.get_env("OSTRICH_LOG_CONSOLE_OUTPUT"); consolOutputEnabled != "" {
        config.logging.consoleOutput = consolOutputEnabled == "true" || consolOutputEnabled == "1"
    }


    if authEnabled := os.get_env("OSTRICH_ENABLE_AUTH"); authEnabled != "" {
        config.security.enableAuth = authEnabled == "true" || authEnabled == "1"
    }

    // CORS overrides
    if origins := os.get_env("OSTRICH_CORS_ALLOWED_ORIGINS"); origins != "" {
        config.cors.allowedOrigins = strings.split(origins, ",")
    }
}

// Validate configuration values
@(require_results)
validate_config :: proc(config: ^lib.AppConfig) -> (err: string) {
    using fmt

    // Validate server config
    if config.server.port < 1 || config.server.port > 65535 {
        return tprintf("Invalid server port: %d (must be 1-65535)", config.server.port)
    }

    if config.server.maxConnections < 1 {
        return "max_connections must be at least 1"
    }

    if config.server.requestTimeoutSeconds < 1 {
        return "request_timeout_seconds must be at least 1"
    }

    // Validate database config
    if config.database.storagePath == "" {
        return "database storage_path cannot be empty"
    }

    if config.database.maxFileSizeMb < 1 {
        return "database max_file_size_mb must be at least 1"
    }

    // Validate logging config
    validLogLevels := []string{"DEBUG", "INFO", "WARN", "ERROR"}
    levelIsValid := false
    for validLevel in validLogLevels {
        if config.logging.level == validLevel {
            levelIsValid = true
            break
        }
    }
    if !levelIsValid {
        return tprintf("Invalid log level: %s (must be DEBUG, INFO, WARN, or ERROR)", config.logging.level)
    }

    // Validate security config
    if config.security.rateLimitRequestsPerMinute < 1 {
        return "rate_limit_requests_per_minute must be at least 1"
    }

    return ""
}

// Get the current loaded configuration
@(require_results)
get_config :: proc() -> ^lib.AppConfig {
    if currentConfig == nil {
        currentConfig = load_config()
    }
    return currentConfig
}

// Reload configuration from file
@(require_results)
reload_config :: proc() -> ^lib.AppConfig {
    if currentConfig != nil {
        free(currentConfig)
    }
    return load_config()
}