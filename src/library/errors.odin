package library

import "core:os"
import "core:fmt"
import "core:strings"
import "base:runtime"
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

UserError::enum {
    NONE = 0,
    CANNOT_DELETE_USER
    //TODO: ADD MORE???
}

UserErrorMessage:= [UserError]string{
    .NONE = "No Error",
    .CANNOT_DELETE_USER = "Could Not Delete Users Account"
}

ProjectLibraryError::enum{
    NONE = 0,
    PROJECTLIB_INVALID_DIRECTORY_STRUCTURE,
    //TODO: ADD MORE?
}

ProjectError::enum{
    NONE = 0,
    PROJECT_NOT_FOUND,
    PROJECT_ALREADY_EXISTS,
    PROJECT_CANNOT_CREATE,
    PROJECT_CANNOT_DELETE,
    PROJECT_CANNOT_RENAME,
    PROJECT_ACCESS_DENIED,
    PROJECT_CANNOT_COUNT_COLLECTIONS,
    PROJECT_CANNOT_LIST_COLLECTIONS,
}
ProjectErrorMessage:=[ProjectError]string{
    .NONE  = "No Project Error",
    .PROJECT_NOT_FOUND = "Project Not Found",
    .PROJECT_ALREADY_EXISTS = "Project Already Exists",
    .PROJECT_CANNOT_CREATE = "Could Not Create Project",
    .PROJECT_CANNOT_DELETE = "Could Not Delete Project",
    .PROJECT_CANNOT_RENAME = "Could Not Rename Project",
    .PROJECT_ACCESS_DENIED = "Access To Project Was Denied",
    .PROJECT_CANNOT_COUNT_COLLECTIONS = "Could Not Count Collections In Project",
    .PROJECT_CANNOT_LIST_COLLECTIONS = "Could Not List Collections In Project",
}

MetadataError ::enum {
    NONE = 0,
    METADATA_CANNOT_INIT,
    METADATA_INVALID_STRUCTURE,
    METADATA_HEADER_NOT_FOUND,
    METADATA_FIELD_NOT_FOUND,
    METADATA_HEADER_ALREADY_EXISTS,
    METADATA_HEADER_CANNOT_APPEND,
    METADATA_CANNOT_UPDATE_FIELD,
    METADATA_CANNOT_UPDATE_FIELDS_AFTER_OPERATION,
    METADATA_CANNOT_GET_FIELD_VALUE,
    METADATA_CANNOT_SET_FFV,
}

SecurityError :: enum {
    NONE = 0,
    SECURITY_CANNOT_STORE_SALT,
    SECURITY_SALT_NOT_FOUND,
    SECURITY_NO_SERVER_SECRET,
    SECURITY_KEY_DERIVATION_FAILED,
    SECURITY_CANNOT_DECRYPT_COLLECTION,
    SECURITY_CANNOT_ENCRYPT_COLLECTION,
    SECURITY_CRITICAL_REENCRYPTION_FAILED,
    SECURITY_INVALID_CONTEXT
}

SecurityErrorMessage:= [SecurityError]string{
    .NONE = "No Error",
    .SECURITY_CANNOT_STORE_SALT = "Failed To Store User Salt",
    .SECURITY_SALT_NOT_FOUND = "User Salt Not Found",
    .SECURITY_NO_SERVER_SECRET = "Server Master Secret Not Configured",
    .SECURITY_KEY_DERIVATION_FAILED = "Failed To Derive User Master Key",
    .SECURITY_CANNOT_DECRYPT_COLLECTION = "Failed To Decrypt Collection",
    .SECURITY_CANNOT_ENCRYPT_COLLECTION = "Failed To Encrypt Collection",
    .SECURITY_CRITICAL_REENCRYPTION_FAILED = "Failed to Re-Encrypt Collection After Operation",
    .SECURITY_INVALID_CONTEXT = "Invalid Project Content"
}


MetadataErrorMessage:= [MetadataError]string{
    . NONE  = "No Error",
    .METADATA_CANNOT_INIT = "Could Not Initialize Metadata Header",
    .METADATA_INVALID_STRUCTURE = "Invalid Metadata Header Structure Detected",
    .METADATA_HEADER_NOT_FOUND = "Could Not Find Metadata Header In Collection",
    .METADATA_FIELD_NOT_FOUND = "Could Not Find Metadata Field",
    .METADATA_HEADER_ALREADY_EXISTS = "A Metadata Header Already Exists In Collection",
    .METADATA_HEADER_CANNOT_APPEND = "Could Not Append Metadata Header To Collection",
    .METADATA_CANNOT_UPDATE_FIELD = "Could Not Update A Metadata Header Field",
    .METADATA_CANNOT_UPDATE_FIELDS_AFTER_OPERATION = "Could Not Update Metadata Field After Operation",
    .METADATA_CANNOT_GET_FIELD_VALUE = "Could Not Get Metadata Field's Value",
    .METADATA_CANNOT_SET_FFV = "Could Not Set File Format Version Value In Metadata Header"
}

CollectionError::enum{
    NONE = 0,
    COLLECTION_NOT_FOUND,
    COLLECTION_ALREADY_EXISTS,
    COLLECTION_INVALID_NAME,
    COLLECTION_INVALID_STRUCTURE,
    COLLECTION_CANNOT_OPEN,
    COLLECTION_CANNOT_READ,
    COLLECTION_CANNOT_CREATE,
    COLLECTION_CANNOT_APPEND_METADATA,
    COLLECTION_CANNOT_UPDATE_METADATA,
    COLLECTION_CANNOT_DELETE,
    COLLECTION_CANNOT_WRITE,
    COLLECTION_CANNOT_UPDATE,
    COLLECTION_CANNOT_PURGE,
    COLLECTION_CANNOT_COUNT_CLUSTERS,
    COLLECTION_CANNOT_COUNT_RECORDS,
    COLLECTION_CANNOT_LIST_CLUSTERS,

}
CollectionErrorMessage:=[CollectionError]string{
    .NONE = "No Collection Error",
    .COLLECTION_NOT_FOUND = "Collection Not Found",
    .COLLECTION_ALREADY_EXISTS = "Collection Already Exists",
    .COLLECTION_INVALID_NAME = "Invalid Collection Name",
    .COLLECTION_INVALID_STRUCTURE = "Collection Has Invalid Structure",
    .COLLECTION_CANNOT_OPEN  = "Could Not Open Collection",
    .COLLECTION_CANNOT_READ = "Could Not Read Collection",
    .COLLECTION_CANNOT_CREATE = "Could Not Create Collection",
    .COLLECTION_CANNOT_APPEND_METADATA = "Could Not Append Metadata Header To Collection",
    .COLLECTION_CANNOT_UPDATE_METADATA = "Could Not Update Collection Metadata Header",
    .COLLECTION_CANNOT_DELETE = "Could Not Delete Collection",
    .COLLECTION_CANNOT_WRITE = "Could Not Write To Collection",
    .COLLECTION_CANNOT_UPDATE = "Could Not Update Collection",
    .COLLECTION_CANNOT_PURGE = "Could Not Purge Collection",
    .COLLECTION_CANNOT_COUNT_CLUSTERS = "Could Not Count Clusters In Collection",
    .COLLECTION_CANNOT_COUNT_RECORDS = "Could Not Count Records In Collection",
    .COLLECTION_CANNOT_LIST_CLUSTERS = "Could Not List Clusters In Collection",
}

ClusterError:: enum{
    NONE = 0,
    CLUSTER_NOT_FOUND,
    CLUSTER_ALREADY_EXISTS,
    CLUSTER_INVALID_STRUCTURE,
    CLUSTER_NAME_INVALID,
    CLUSTER_CANNOT_READ,
    CLUSTER_CANNOT_CREATE,
    CLUSTER_CANNOT_DELETE,
    CLUSTER_CANNOT_UPDATE,
    CLUSTER_CANNOT_PURGE,
    CLUSTER_CANNOT_WRITE,
    CLUSTER_CONTAINS_NO_DATA,
    CLUSTER_CANNOT_COUNT,
}
ClusterErrorMessage:=[ClusterError]string{
    .NONE = "No Cluster Error",
    .CLUSTER_NOT_FOUND = "Cluster Not Found",
    .CLUSTER_ALREADY_EXISTS = "Cluster Already Exists",
    .CLUSTER_INVALID_STRUCTURE = "Cluster Has Invalid Structure",
    .CLUSTER_NAME_INVALID = "Cluster Name Is Invalid",
    .CLUSTER_CANNOT_READ = "Could Not Read Cluster",
    .CLUSTER_CANNOT_CREATE = "Could Not Create Cluster",
    .CLUSTER_CANNOT_DELETE = "Could Not Delete Cluster",
    .CLUSTER_CANNOT_UPDATE = "Could Not Update Cluster",
    .CLUSTER_CANNOT_PURGE = "Could Not Purge Cluster",
    .CLUSTER_CANNOT_WRITE = "Could Not Write Cluster To Collection",
    .CLUSTER_CONTAINS_NO_DATA = "Cluster Contains No Data",
    .CLUSTER_CANNOT_COUNT = "Could Not Count Records In Cluster",
}

RecordError::enum{
    NONE = 0,
    RECORD_CANNOT_PARSE,
    RECORD_INVALID_VALUE,
    RECORD_NOT_FOUND,
    RECORD_ALREADY_EXISTS,
    RECORD_CANNOT_READ,
    RECORD_CANNOT_CREATE,
    RECORD_CANNOT_DELETE,
    RECORD_CANNOT_UPDATE,
    RECORD_CANNOT_PURGE,
    RECORD_CANNOT_GET,
    RECORD_CANNOT_GET_BY_ID,
    RECORD_CANNOT_GET_NAME,
    RECORD_CANNOT_GET_TYPE,
    RECORD_CANNOT_GET_VALUE,
    RECORD_CANNOT_GET_VALUE_SIZE,
    RECORD_CANNOT_FILTER,
    RECORD_CONVERT_TYPE,
}
RecordErrorMessage:=[RecordError]string{
    .NONE = "No Record Error",
    .RECORD_CANNOT_PARSE = "Could Not Parse Record Data",
    .RECORD_INVALID_VALUE = "Record Has Invalid Value",
    .RECORD_NOT_FOUND = "Record Not Found",
    .RECORD_ALREADY_EXISTS = "Record Already Exists",
    .RECORD_CANNOT_READ = "Could Not Read Record",
    .RECORD_CANNOT_CREATE = "Could Not Create Record",
    .RECORD_CANNOT_DELETE = "Could Not Delete Record",
    .RECORD_CANNOT_UPDATE = "Could Not Update Record",
    .RECORD_CANNOT_PURGE = "Could Not Purge Record",
    .RECORD_CANNOT_GET = "Could Not Get Record",
    .RECORD_CANNOT_GET_BY_ID = "Could Not Get Record By ID",
    .RECORD_CANNOT_GET_NAME = "Could Not Get Records Name",
    .RECORD_CANNOT_GET_TYPE = "Could Not Get Records Type",
    .RECORD_CANNOT_GET_VALUE = "Could Not Get Records Value",
    .RECORD_CANNOT_GET_VALUE_SIZE = "Could Not Get Record Value Size",
    .RECORD_CANNOT_FILTER = "Could Not Filter Records",
    .RECORD_CONVERT_TYPE = "Could Not Convert Record Type",
}

ComplexDataError::enum{
    NONE = 0,
    COMPLEX_CANNOT_PARSE_DATA,
    COMPLEX_CANNOT_PARSE_ARRAY,
    COMPLEX_CANNOT_FORMAT_ARRAY,
    COMPLEX_CANNOT_VERIFY_ARRAY_VALUES,
    COMPLEX_INVALID_DATE_LENGTH,
    COMPLEX_INVALID_DATE_FORMAT,
    COMPLEX_INVALID_TIME_LENGTH,
    COMPLEX_INVALID_TIME_FORMAT,
    COMPLEX_INVALID_DATETIME_LENGTH,
    COMPLEX_INVALID_DATETIME_FORMAT,
    COMPLEX_INVALID_UUID_LENGTH,
    COMPLEX_INVALID_UUID_FORMAT,
}
ComplexDataErrorMessage:=[ComplexDataError]string{
    .NONE = "No Error",
    .COMPLEX_CANNOT_PARSE_DATA = "Could Not Parse Complex Data",
    .COMPLEX_CANNOT_PARSE_ARRAY = "Could Not Parse Array",
    .COMPLEX_CANNOT_FORMAT_ARRAY = "Could Not Format Array Data",
    .COMPLEX_CANNOT_VERIFY_ARRAY_VALUES = "Could Not Verify Array Values",
    .COMPLEX_INVALID_DATE_LENGTH = "Invalid Date Length Detected",
    .COMPLEX_INVALID_DATE_FORMAT = "Invalid Date Format Detected",
    .COMPLEX_INVALID_TIME_LENGTH = "Invalid Time Length Detected",
    .COMPLEX_INVALID_TIME_FORMAT =  "Invalid Time Format Detected",
    .COMPLEX_INVALID_DATETIME_LENGTH = "Invalid DateTime Length Detected",
    .COMPLEX_INVALID_DATETIME_FORMAT =  "Invalid DateTime Format Detected",
    .COMPLEX_INVALID_UUID_LENGTH = "Invalid UUID Length Detected",
    .COMPLEX_INVALID_UUID_FORMAT =  "Invalid UUID Format Detected",
}

DataConversionError::enum{
    NONE = 0,
    UNKNOWN,
    DATA_CONVERSION_TYPES_MATCH,
    DATA_CONVERSION_WITH_TYPE_CHANGE,
    DATA_CONVERSION_CANNOT_CONVERT_TO_INTEGER,
    DATA_CONVERSION_CANNOT_CONVERT_TO_STRING,
    DATA_CONVERSION_CANNOT_CONVERT_TO_BOOLEAN,
    DATA_CONVERSION_CANNOT_CONVERT_TO_FLOAT,
    DATA_CONVERSION_CANNOT_CONVERT_TO_DATE,
    DATA_CONVERSION_CANNOT_CONVERT_TO_TIME,
    DATA_CONVERSION_CANNOT_CONVERT_TO_DATETIME,
    DATA_CONVERSION_CANNOT_CONVERT_TO_UUID,
    DATA_CONVERSION_CANNOT_CONVERT_TO_INT_ARRAY,
    DATA_CONVERSION_CANNOT_CONVERT_TO_STR_ARRAY,
    DATA_CONVERSION_CANNOT_CONVERT_TO_BOOL_ARRAY,
    DATA_CONVERSION_CANNOT_CONVERT_TO_FLT_ARRAY,
    DATA_CONVERSION_CANNOT_CONVERT_TO_DATE_ARRAY,
    DATA_CONVERSION_CANNOT_CONVERT_TO_TIME_ARRAY,
    DATA_CONVERSION_CANNOT_CONVERT_TO_DT_ARRAY, //datetime
    DATA_CONVERSION_CANNOT_CONVERT_TO_UUID_ARRAY,
}
DataConversionErrorMessage:= [DataConversionError]string{
    .NONE = "No Error",
    .UNKNOWN = "Unknown Data Conversion Error",
    .DATA_CONVERSION_TYPES_MATCH = "Data Types Already Match - No Conversion Needed",
    .DATA_CONVERSION_WITH_TYPE_CHANGE = "Could Not Convert Record Value Based On New Type",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_INTEGER = "Could Not Convert To Integer",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_STRING = "Could Not Convert To String",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_BOOLEAN = "Could Not Convert To Boolean",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_FLOAT = "Could Not Convert To Float",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_DATE = "Could Not Convert To Date",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_TIME = "Could Not Convert To Time",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_DATETIME = "Could Not Convert To DateTime",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_UUID = "Could Not Convert To UUID",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_INT_ARRAY = "Could Not Convert To Integer Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_STR_ARRAY = "Could Not Convert To String Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_BOOL_ARRAY = "Could Not Convert To Boolean Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_FLT_ARRAY = "Could Not Convert To Float Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_DATE_ARRAY = "Could Not Convert To Date Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_TIME_ARRAY = "Could Not Convert To Time Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_DT_ARRAY = "Could Not Convert To DateTime Array",
    .DATA_CONVERSION_CANNOT_CONVERT_TO_UUID_ARRAY = "Could Not Convert To UUID Array",

}

ConfigError:: enum{
    NONE = 0,
    CONFIG_CANNOT_LOAD_CONFIG,
}
ConfigErrorMessage:=[ConfigError]string{
    .NONE = "No Error",
    .CONFIG_CANNOT_LOAD_CONFIG = "Could Not Load Configuration",
}


StandardError:: enum{
    STANDARD_NONE = 0,
    UNKNOWN_ERROR,
    STANDARD_CANNOT_OPEN_DIRECTORY,
    STANDARD_CANNOT_READ_DIRECTORY,
    STANDARD_CANNOT_CREATE_DIRECTORY,
    STANDARD_CANNOT_CREATE_FILE,
    STANDARD_CANNOT_READ_FILE,
    STANDARD_CANNOT_WRITE_TO_FILE,
    STANDARD_CANNOT_OPEN_FILE,
    STANDARD_CANNOT_READ_INPUT,
    STANDARD_CANNOT_GENERATE_CACHE_FILE,

}
StandardErrorMessage:=[StandardError]string{
    .STANDARD_NONE = "No Error",
    .UNKNOWN_ERROR = "Unknown Error",
    .STANDARD_CANNOT_OPEN_DIRECTORY = "Could Not Open Directory",
    .STANDARD_CANNOT_READ_DIRECTORY = "Could Not Read Directory",
    .STANDARD_CANNOT_CREATE_DIRECTORY = "Could Not Create Directory",
    .STANDARD_CANNOT_CREATE_FILE = "Could Not Create File",
    .STANDARD_CANNOT_READ_FILE = "Could Not Read File",
    .STANDARD_CANNOT_WRITE_TO_FILE = "Could Not Write To File",
    .STANDARD_CANNOT_OPEN_FILE = "Could Not Open File",
    .STANDARD_CANNOT_READ_INPUT = "Could Not Read User Input",
    .STANDARD_CANNOT_GENERATE_CACHE_FILE = "Failed To Generate cache.yml file",
}

ServerError:: enum{
    NONE = 0,
    SERVER_CANNOT_LOG_EVENT,
    SERVER_NO_BYTES_READ,
    SERVER_CANNOT_LISTEN_ON_SOCKET,
    SERVER_CANNOT_ACCEPT_CONNECTION,
    SERVER_CANNOT_READ_FROM_SOCKET,
    SERVER_CANNOT_WRITE_RESPONSE_TO_SOCKET,
}
ServerErrorMessage:= [ServerError]string{
    .NONE = "No Error" ,
    .SERVER_CANNOT_LOG_EVENT = "Server Failed To Log Event",
    .SERVER_NO_BYTES_READ = "Server Read Zero Bytes From Client Socket",
    .SERVER_CANNOT_LISTEN_ON_SOCKET = "Server Failed To Listen On TCP Socket" ,
    .SERVER_CANNOT_ACCEPT_CONNECTION = "Server Failed To Accept Client TCP Socket Connection" ,
    .SERVER_CANNOT_READ_FROM_SOCKET = "Server Failed To Read From Client TCP Socket" ,
    .SERVER_CANNOT_WRITE_RESPONSE_TO_SOCKET = "Server Failed To Write Response" ,
}

QueryError :: enum{
    NONE = 0,
    QUERY_CANNOT_BE_EMPTY,
    QUERY_CANNOT_PARSE,
    QUERY_INVALID_COMMAND_TOKEN,
    QUERY_INVALID_PARAM_TOKEN,
}

QueryErrorMessage := [QueryError]string{
    .NONE= "No Error",
    .QUERY_CANNOT_BE_EMPTY = "Queries cannot be empty",
    .QUERY_CANNOT_PARSE = "Failed to parse query",
    .QUERY_INVALID_COMMAND_TOKEN = "Invalid command token found in query",
    .QUERY_INVALID_PARAM_TOKEN = "Invalid parameter token(s) found in query"
}

OstrichError::union{
    // Error Types
    QueryError,
    UserError,
    ProjectLibraryError,
    ProjectError,
    MetadataError,
    SecurityError,
    CollectionError,
    ClusterError,
    RecordError,
    ComplexDataError,
    DataConversionError,
    StandardError,
    ServerError,

    //Error struct
    Error
}


Error :: struct {
	message:   string,
	location:  runtime.Source_Code_Location
}

//ERROR HELPER PROCEDURES BELOW

//Gets an returns a source code location. e.g: File, line, column, etc
get_caller_location :: proc(location:= #caller_location) -> SourceCodeLocation {
    return location
}


//Returns the appropriate error message fot the passed in error
get_err_msg :: proc(error: OstrichError) -> (string) {
    #partial switch err in error {
    // case AuthError:
        // return AuthErrorMessage[err] or_else "Unknown authentication error"
    // case ProjectLibraryError:
        // return ProjectLibraryErrorMessage[err] or_else "Unknown project library error"
    case QueryError:
        return QueryErrorMessage[err]
    case UserError:
        return UserErrorMessage[err]
    case ProjectError:
        return ProjectErrorMessage[err]
    case MetadataError:
        return MetadataErrorMessage[err]
    case SecurityError:
        return SecurityErrorMessage[err]
    case CollectionError:
        return CollectionErrorMessage[err]
    case ClusterError:
        return ClusterErrorMessage[err]
    case RecordError:
        return RecordErrorMessage[err]
    case ComplexDataError:
        return ComplexDataErrorMessage[err]
    case DataConversionError:
        return DataConversionErrorMessage[err]
    case StandardError:
        return StandardErrorMessage[err]
    }
    return "Unknown error"
}


//Throws the  passed in error information onto the console
throw_err :: proc(error: ^Error) {
		fmt.printfln("%s%s[ERROR]%s", RED, BOLD, RESET)
		fmt.printfln(
			"ERROR%s occurred in...\nFile: [%s%s%s]\nOstrichDB Procedure: [%s%s%s] @ Line: [%s%d%s]\nError Message: [%s%s%s]",
			RESET,
			BOLD,
			error.location.file_path,
			RESET,
			BOLD,
			error.location.procedure,
			RESET,
			BOLD,
			error.location.line,
			RESET,
			BOLD,
			error.message,
			RESET,
		)
}

//Handles all error related shit, just pass it the two args and you are good. - Marshall
make_new_err :: proc(err:OstrichError, location:SourceCodeLocation) -> ^Error{
    message:= get_err_msg(err)

    error:= new(Error)
    error.message = message
    error.location = location

    throw_err(error)
    return error
}

// Helper for success case
no_error :: proc() -> ^Error {
    return nil
}
