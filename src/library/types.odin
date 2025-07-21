package library

import "core:time"
import "base:runtime"
import "core:strings"
import "core:strconv"
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
//GENERAL TYPES START

StandardUserCredential :: struct {
	Value:  string, //username
	Length: int, //length of the username
}

SpecialUserCredential :: struct {
	valAsBytes: []u8,
	valAsStr:   string,
}

User :: struct {
	user_id:        i64,
	role:           StandardUserCredential,
	username:       StandardUserCredential,
	password:       StandardUserCredential,
	salt:           SpecialUserCredential,
	hashedPassword: SpecialUserCredential, //this is the hashed password without the salt
	store_method:   int,
	m_k:            SpecialUserCredential, //master key
}


IdType :: enum{
    UserID = 0,
    ClusterID,
    RecordID
}


HashMethod :: enum {
    SHA3_224 = 0,
    SHA3_256,
    SHA3_384,
    SHA3_512,
    SHA512_256
}

system_user: User = { 	//OstrichDB itself
	user_id = -1,
	username = StandardUserCredential{Value = "OstrichDB", Length = 11},
	m_k = SpecialUserCredential {
		valAsBytes = []u8 {
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
		},
		valAsStr = "8F2A1D5E9C4B7F3A6D0E8B2C5F9A7D4E1B3C6A8D2E5F7C9B4A1D8E3F6C9B2A5",
	},
}

OstrichDBEngine:: struct{
    EngineRuntime: time.Duration,
    Server: Server
    //more??
}
//GENERAL TYPES END


//DATA RELATED TYPES START
DataStructureTier :: enum {
    COLLECTION = 0,
    CLUSTER,
    RECORD,
}

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
	name:           string,
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
	CRITICAL_ERROR
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

QueryToken :: enum{
    INVALID = 0,
    //Command tokens
    NEW,
    ERASE,
    FETCH,
    RENAME,
    SET,
    PURGE,
    //parameter tokens
    TO,
    OF_TYPE,
    WITH,
    //Create and add more???
}

QueryTokenString :: #partial[QueryToken]string{
    .NEW = "NEW",
    .ERASE = "ERASE",
    .RENAME = "RENAME",
    .FETCH = "FETCH",
    .SET = "SET",
    .PURGE = "PURGE",
    .TO = "TO",
    .OF_TYPE = "OF_TYPE",
    .WITH = "WITH",
}

TokenStrings :: #partial[QueryToken]string{
    //command token strings
    .NEW = "NEW",
    .ERASE = "ERASE",
    .FETCH = "FETCH",
    .RENAME = "RENAME",
    .SET = "SET",
    .PURGE = "PURGE",
    //parameter token strings
    .TO = "TO",
    .OF_TYPE = "OF_TYPE",
    .WITH = "WITH",

}

Query :: struct {
    CommandToken : QueryToken,
    LocationToken: [dynamic]string,
    ParameterToken: map[string]string,
    isChained: bool,
    rawInput: string
}

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

//TODO: Add date filtering???

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
