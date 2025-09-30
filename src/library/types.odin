package library

import "core:time"
import "base:runtime"
import "core:strings"
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
            This file contains all the logic for interacting with
            collections within the OstrichDB engine.
*********************************************************/
//GENERAL TYPES START

User :: struct {
    id, email: string
    //Todo: Add more??
}

RateLimitInfo :: struct {
    count: int,
    windowStart: time.Time,
    lastRequest: time.Time,
}


HashMethod :: enum {
    SHA3_224 = 0,
    SHA3_256,
    SHA3_384,
    SHA3_512,
    SHA512_256
}

OstrichDBEngine:: struct{
    EngineRuntime: time.Duration,
    Server: Server
    //more??
}
//GENERAL TYPES END

CollectionType :: enum {
    STANDARD = 0 ,
    BACKUP,
    //Add more if needed
}

Collection :: struct {
    name: string,
    type: CollectionType,
    numberOfClusters: int,
    clusters: [dynamic]Cluster, //might not do this
    // size: int //Bytes??? or fileInfo.size???
}

Cluster :: struct {
    parent: Collection,
    name: string,
    id: i64,
    numberOfRecords: int,
    records: [dynamic]Record, //might not do this
    // size: int //in bytes??
}

Record :: struct{
    grandparent: Collection,
    parent: Cluster,
    id: i64,
    name,  value:string,
    type: RecordDataTypes,
    typeAsString: string
    // size:int //in bytes??
}

RecordDataTypes :: enum {
    INVALID = 0,
    CREDENTIAL = 1,
	NULL,
    CHAR,
    STR,
	STRING,
	INT,
	INTEGER,
	FLT,
	FLOAT,
	BOOL,
	BOOLEAN,
	DATE,
	TIME,
	DATETIME,
	UUID,
	CHAR_ARRAY,
	STR_ARRAY,
	STRING_ARRAY,
	INT_ARRAY,
	INTEGER_ARRAY,
	FLT_ARRAY,
	FLOAT_ARRAY,
	BOOL_ARRAY,
	BOOLEAN_ARRAY,
	DATE_ARRAY,
	TIME_ARRAY,
	DATETIME_ARRAY,
	UUID_ARRAY,
}

@(rodata)
RecordDataTypesStrings := [RecordDataTypes]string {
    .INVALID = "INVALID",
    .CREDENTIAL = "CREDENTIAL",
    .NULL = "NULL" ,
    .CHAR = "CHAR" ,
    .STR = "STR" ,
    .STRING = "STRING" ,
    .INT = "INT" ,
    .INTEGER = "INTEGER" ,
    .FLT = "FLT" ,
    .FLOAT = "FLOAT" ,
    .BOOL = "BOOL" ,
    .BOOLEAN = "BOOLEAN" ,
    .DATE = "DATE" ,
    .TIME = "TIME" ,
    .DATETIME = "DATETIME" ,
    .UUID = "UUID" ,
    .CHAR_ARRAY = "[]CHAR" ,
    .STR_ARRAY = "[]STRING" ,
    .STRING_ARRAY = "[]STRING" ,
    .INT_ARRAY = "[]INTEGER" ,
    .INTEGER_ARRAY = "[]INTEGER" ,
    .FLT_ARRAY = "[]FLOAT" ,
    .FLOAT_ARRAY = "[]FLOAT" ,
    .BOOL_ARRAY = "[]BOOLEAN" ,
    .BOOLEAN_ARRAY = "[]BOOLEAN" ,
    .DATE_ARRAY = "[]DATE" ,
    .TIME_ARRAY = "[]TIME" ,
    .DATETIME_ARRAY = "[]DATETIME" ,
    .UUID_ARRAY = "[]UUID" ,
}

//DATA RELATED TYPES END


MetadataField :: enum {
    ENCRYPTION_STATE = 0,
    FILE_FORMAT_VERSION,
    PERMISSION,
    DATE_CREATION,
    DATE_MODIFIED,
    FILE_SIZE,
    CHECKSUM,
}


//SERVER RELATED START
Server :: struct {
    port: int,
    //more??
}

HttpStatusCode :: enum{
    //2xx codes
    OK                  = 200,
    CREATE              = 201,
    NO_CONTENT          = 204,
    PARTIAL_CONTENT     = 206,
    //3xx codes
    MOVED_PERMANENTLY   = 301,
    FOUND               = 302,
    NOT_MODIFIED        = 304,
    //4xx codes
    BAD_REQUEST         = 400,
    UNAUTHORIZED        = 401,
    FORBIDDEN           = 403,
    NOT_FOUND           = 404,
    METHOD_NOT_ALLOWED  = 405,
    CONFLICT            = 409,
    PAYLOAD_TOO_LARGE   = 413,
    UNSUPPORTED_MEDIA   = 415,
    TOO_MANY_REQUESTS   = 429,
    //5xx codes
    SERVER_ERROR        = 500,
    NOT_IMPLEMENTED     = 501,
    BAD_GATEWAY         = 502,
    SERVICE_UNAVAILABLE = 503,
    GATEWAY_TIMEOUT     = 504,
}

HttpStatus :: struct {
    statusCode: HttpStatusCode,
    text: string
    //more??
}

HttpMethod :: enum {
    HEAD = 0,
    GET,
    POST,
    PUT,
    DELETE,
    OPTIONS,
}

HttpMethodString := [HttpMethod]string{
    .HEAD = "HEAD",
    .GET    = "GET",
    .POST    = "POST",
    .PUT    = "PUT",
    .DELETE    = "DELETE",
    .OPTIONS = "OPTIONS",
}

//All request handler procecures which are located in in handlers.odin need to follow this signature.
//Note: 'args'  are only passed when makeing a POST or GET request
RouteHandler ::proc(method: HttpMethod,path:string, headers:map[string]string, args:[]string) -> (^HttpStatus, string)

Route :: struct {
    method: HttpMethod,
    path: string,
    handler: RouteHandler
}

Router :: struct {
    routes: [dynamic]Route
}

//Cant find docs on #sparse. Just used the compilers error message if you removed it
HttpStatusText :: #sparse[HttpStatusCode]string {
    //2xx codes
    .OK                  = "OK",
    .CREATE              = "Created",
    .NO_CONTENT          = "No Content",
    .PARTIAL_CONTENT     = "Partial Content",
    //3xx codes
    .MOVED_PERMANENTLY   = "Moved Permanently",
    .FOUND               = "Found",
    .NOT_MODIFIED        = "Not Modified",
    //4xx codes
    .BAD_REQUEST         = "Bad Request",
    .UNAUTHORIZED        = "Unauthorized",
    .FORBIDDEN           = "Forbidden",
    .NOT_FOUND           = "Not Found",
    .METHOD_NOT_ALLOWED  = "Method Not Allowed",
    .CONFLICT            = "Conflict",
    .PAYLOAD_TOO_LARGE   = "Payload Too Large",
    .UNSUPPORTED_MEDIA   = "Unsupported Media Type",
    .TOO_MANY_REQUESTS   = "Too Many Requests",
    //5xx codes
    .SERVER_ERROR        = "Internal Server Error",
    .NOT_IMPLEMENTED     = "Not Implemented",
    .BAD_GATEWAY         = "Bad Gateway",
    .SERVICE_UNAVAILABLE = "Service Unavailable",
    .GATEWAY_TIMEOUT     = "Gateway Timeout",
}

ServerSession :: struct {
    Id:                 i64,
    start_timestamp:     time.Time,
    end_timestamp:      time.Time,
    total_runtime:          time.Duration
}


ServerEvent :: struct {
	description:    string,
	type:           ServerEventType,
	timestamp:      time.Time,
	isRequestEvent: bool,
	route:          Route,
	statusCode:     HttpStatusCode,
}

ServerEventType :: enum {
	ROUTINE = 0,
	WARNING,
	ERROR,
	CRITICAL_ERROR,
	SUCCESS
}
//For error logging

// CorsOptions defines the configuration for CORS
CorsOptions :: struct {
    allowOrigins: []string,           // List of allowed origins, use ["*"] for all
    allowMethods: []HttpMethod,   // List of allowed HTTP methods
    allowHeaders: []string,           // List of allowed headers
    exposeHeaders: []string,          // List of headers exposed to the browser
    allowCredentials: bool,           // Whether to allow credentials (cookies, etc.)
    maxAge: int,                      // How long preflight requests can be cached (in seconds)
}


//Type alias for source code location info
SourceCodeLocation::runtime.Source_Code_Location
#assert(SourceCodeLocation == runtime.Source_Code_Location)

// User-specific path configuration for isolated user environments
UserPathConfig :: struct {
    userID:       string,
    basePath:     string,  // ./projects/{userID}/
    projectsPath: string,  // ./projects/{userID}/projects/
    backupsPath:  string,  // ./projects/{userID}/backups/
    logsPath:     string,  // ./projects/{userID}/logs/
    tempPath:     string,  // ./projects/{userID}/temp/
}

//PROJECT, DYNAMIC PATH,  AND CONFIG TYPES START
ProjectLibraryContext ::struct{
    basePath: string
}

// Project context that gets passed back and forth instead of hardcoded paths. For individual projects
ProjectContext :: struct {
    projectID:   string,
    projectName: string,
    userID:      string,
    basePath:    string,
    subCollections: [dynamic]^Collection,
    subCollectionCount: int,
    environment:  string, // "development", "production", "testing"
}

// Project metadata structure
ProjectMetadata :: struct {
    projectID:   string,
    projectName: string,
    userID:      string,
    createdAt:   time.Time,
    version:      string,
}


// Dynamic path configuration that replaces hardcoded paths
DynamicPathConfig :: struct {
    rootPath:              string,
    projectBasePath:     string,
    systemBasePath:       string,
    logBasePath:         string,
    tempBasePath:         string,
}

ServerConfig :: struct {
    port:                  int    `json:"port"`,
    host:                  string `json:"host"`,
    bindAddress:           string `json:"bindAddress"`,
    maxConnections:        int    `json:"maxConnections"`,
    requestTimeoutSeconds: int    `json:"requestTimeoutSeconds"`,
    backlogSize:          int    `json:"backlogSize"`,
    filePath:               string `json:"filePath"`,
}

DatabaseConfig :: struct {
    storagePath:          string `json:"storagePath"`,
    maxFileSizeMb:        int    `json:"maxFileSizeMb"`,
    backupEnabled:        bool   `json:"backupEnabled"`,
    backupIntervalHours:  int    `json:"backupIntervalHours"`,
}

LoggingConfig :: struct {
    level:            string `json:"level"`,
    filePath:         string `json:"filePath"`,
    consoleOutput:    bool   `json:"consoleOutput"`,
    maxFileSizeMb:    int    `json:"maxFileSizeMb"`,
    rotateFiles:      bool   `json:"rotateFiles"`,
    maxRotatedFiles:  int    `json:"maxRotatedFiles"`,
}

CorsConfig :: struct {
    allowedOrigins:   []string `json:"allowedOrigins"`,
    allowedMethods:   []HttpMethod `json:"allowedMethods"`,
    allowedHeaders:   []string `json:"allowedHeaders"`,
    exposeHeaders:    []string `json:"exposeHeaders"`,
    maxAgeSeconds:    int      `json:"maxAgeSeconds"`,
    allowCredentials: bool     `json:"allowCredentials"`,
}

SecurityConfig :: struct {
    rateLimitRequestsPerMinute: int    `json:"rateLimitRequestsPerMinute"`,
    maxRequestBodySizeMb:      int    `json:"maxRequestBodySizeMb"`,
    enableAuth:                bool   `json:"enableAuth"`,
}

AppConfig :: struct {
    server:   ServerConfig   `json:"server"`,
    database: DatabaseConfig `json:"database"`,
    logging:  LoggingConfig  `json:"logging"`,
    cors:     CorsConfig     `json:"cors"`,
    security: SecurityConfig `json:"security"`,
}


// Enhanced query parameter structure
QueryParams :: struct {
    recordType: string,  // ?type=STRING
    recordID: i64,       // ?id=5
    limit: int,          // ?limit=10
    offset: int,         // ?offset=20
    search: string,      // ?search=john (search in record names)
    value: string,       // ?value=active (search in record values)
    valueContains: string, // ?valueContains=test (partial value match)
    sortBy: string,      // ?sortBy=name|value|type|id
    sortOrder: string,   // ?sortOrder=asc|desc
    minValue: string,    // ?minValue=100 (for numeric comparisons)
    maxValue: string,    // ?maxValue=500 (for numeric comparisons)
    dateFrom: string,    // ?dateFrom=2024-01-01 (for date ranges)
    dateTo: string,      // ?dateTo=2024-12-31 (for date ranges)
}

SortField :: enum {
    NAME = 0,
    VALUE,
    TYPE,
    ID,
}

SortOrder :: enum {
    ASC = 0,
    DESC,
}

SearchCriteria :: struct {
    namePattern: string,
    valuePattern: string,
    typeFilter: RecordDataTypes,
    valueRange: struct{
        min: string,
        max: string,
        hasMin: bool,
        hasMax: bool,
    },
    sortField: SortField,
    sortOrder: SortOrder,
}

ErrorEvent :: struct {
    description:    string,
    type:           ErrorEventType,
    severity:       ErrorSeverity,
    timestamp:      time.Time,
    // error_code:     OstrichError,
}

ErrorSeverity :: enum {
    DEBUG = 0,
    INFO,
    WARNING,
    ERROR,
    CRITICAL,
}

ErrorEventType :: enum {

    // Subsystem Categories
    DATABASE_ENGINE,    // Core database operations
    AUTHENTICATION,     // JWT, user validation, permissions
    SECURITY,          // Encryption, key management, access control
    NETWORK,           // TCP connections, HTTP requests, timeouts
    FILE_SYSTEM,       // File I/O, permissions, disk space
    MEMORY,            // Allocation failures, leaks, OOM
    CONFIGURATION,     // Config loading, validation, environment
    PERFORMANCE,       // Slow queries, resource exhaustion

    // Operation Types
    CREATE_OPERATION,  // Project/collection/cluster/record creation
    READ_OPERATION,    // Data retrieval operations
    UPDATE_OPERATION,  // Data modification operations
    DELETE_OPERATION,  // Data deletion operations
    SEARCH_OPERATION,  // Query and search operations

    // Infrastructure
    BACKUP_FAILURE,    // Backup/restore operations
    RATE_LIMITING,     // Rate limit violations
    VALIDATION_ERROR,  // Data validation failures
    PARSING_ERROR,     // JSON/data parsing issues
    TRANSACTION_ERROR, // Future transaction failures

    API_ERROR,         // REST API specific errors
}



//Manual Query Editor Shit
Query :: struct {
	commandToken:            Token, //command token
	locationToken:            [dynamic]string, //location token
	paramToken:            map[string]string, //parameter token
	targetToken:            string, //target token only needed for very specific commands like WHERE,HELP, and NEW USER
	isChained:         bool,
	rawInput:          string
}

QueryParserState :: enum {
    EXPECTING_COMMAND_TOKEN = 0,
    EXPECTING_PARAM_TOKEN,
    EXPECTING_VALUE
}

Command :: struct {
	c_token:            Token, //command token
	l_token:            [dynamic]string, //location token
	p_token:            map[string]string, //parameter token
	t_token:            string, //target token only needed for very specific commands like WHERE,HELP, and NEW USER
	isChained:         bool,
	rawInput:          string
}

TokenType:: enum {
    COMMAND= 0,
    PARAM,
    TARGET,
}

Token :: enum {
	//Command tokens
	INVALID,
	DESTROY,
	VERSION,
	HELP,
	CLEAR,
	TREE,
	HISTORY,
	WHERE,
	NEW,
	BACKUP,
	ERASE,
	RENAME,
	FETCH,
	COUNT,
	SET,
	PURGE,
	SIZE_OF,
	TYPE_OF,
	CHANGE_TYPE,
	//Parameter tokens
	WITH,
	OF_TYPE,
	TO,
	//Shorthand and traditional basic type tokens
	STR,
	STRING,
	INT,
	INTEGER,
	FLT,
	FLOAT,
	BOOL,
	BOOLEAN,
	CHAR,
	//shorthand and traditional complex types
	STR_ARRAY,
	STRING_ARRAY,
	INT_ARRAY,
	INTEGER_ARRAY,
	FLT_ARRAY,
	FLOAT_ARRAY,
	BOOL_ARRAY,
	BOOLEAN_ARRAY,
	CHAR_ARRAY,
	//More advance complex types...They follow ISO 8601 format
	DATE,
	TIME,
	DATETIME,
	DATE_ARRAY,
	TIME_ARRAY,
	DATETIME_ARRAY,
	//Misc types
	UUID,
	UUID_ARRAY,
	NULL,
	// Lesser used target tokens
	COLLECTION,
	COLLECTIONS,
	CLUSTER,
	CLUSTERS,
	RECORD,
	RECORDS,
	// General purpose misc tokens
	CLPS,
	CLP,
	YES,
	NO,
	CONFIRM,
	CANCEL,
	//Not using any tokens below this point yet... - Marshall
	// TEST,
	// ALL,
	// AND,
	// ALL_OFF,
}


TokenStr := #partial [Token]string {
	.DESTROY        = "DESTROY",
	.VERSION        = "VERSION",
	.HELP           = "HELP",
	.CLEAR          = "CLEAR",
	.TREE           = "TREE",
	.HISTORY        = "HISTORY",
	.WHERE          = "WHERE",
	//Command Tokens
	.NEW            = "NEW",
	.BACKUP         = "BACKUP",
	.ERASE          = "ERASE",
	.RENAME         = "RENAME",
	.FETCH          = "FETCH",
	.COUNT          = "COUNT",
	.SET            = "SET",
	.PURGE          = "PURGE",
	.SIZE_OF        = "SIZE_OF",
	.TYPE_OF        = "TYPE_OF",
	.CHANGE_TYPE    = "CHANGE_TYPE",
	//Parameter tokens
	.WITH            = "WITH",
	.OF_TYPE        = "OF_TYPE",
	.TO             = "TO",
	//Shorthand and traditional basic type tokens
	.CHAR           = "CHAR",
	.STR            = "STR",
	.STRING         = "STRING",
	.INT            = "INT",
	.INTEGER        = "INTEGER",
	.FLT            = "FLT",
	.FLOAT          = "FLOAT",
	.BOOL           = "BOOL",
	.BOOLEAN        = "BOOLEAN",
	//shorthand and traditional complex types
	.CHAR_ARRAY     = "[]CHAR",
	.STR_ARRAY      = "[]STR",
	.STRING_ARRAY   = "[]STRING",
	.INT_ARRAY      = "[]INT",
	.INTEGER_ARRAY  = "[]INTEGER",
	.FLT_ARRAY      = "[]FLT",
	.FLOAT_ARRAY    = "[]FLOAT",
	.BOOL_ARRAY     = "[]BOOL",
	.BOOLEAN_ARRAY  = "[]BOOLEAN",
	//More advance complex types...They follow ISO 8601 format
	.DATE           = "DATE",
	.TIME           = "TIME",
	.DATETIME       = "DATETIME",
	.DATE_ARRAY     = "[]DATE",
	.TIME_ARRAY     = "[]TIME",
	.DATETIME_ARRAY = "[]DATETIME",
	//Misc types
	.UUID           = "UUID",
	.UUID_ARRAY     = "[]UUID",
	.NULL           = "NULL",
	// Lesser used target tokens
	.COLLECTION     = "COLLLECTION",
	.COLLECTIONS    = "COLLECTIONS",
	.CLUSTER        = "CLUSTER",
	.CLUSTERS       = "CLUSTERS",
	.RECORD         = "RECORD",
	.RECORDS        = "RECORDS",
	// General purpose misc tokens
	.CLP            = "CLP",
	.CLPS           = "CLPS",
	.YES            = "YES",
	.NO             = "NO",
	.CONFIRM        = "CONFIRM",
	.CANCEL         = "CANCEL",
	//Not using any tokens below this point yet... - Marshall
	// .TEST = "TEST",
	// .ALL = "ALL",
	// .AND = "AND",
	// .ALL_OFF = "ALL_OFF",
}