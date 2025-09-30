package data

import "core:fmt"
import "core:strings"
import "core:strconv"
import "../../config"
import lib"../../../library"
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
            Contains logic for handling the conversion of record data
            types within OstrichDB
*********************************************************/

//The following conversion procs are used to convert the passed in record value to the correct data type
@(require_results)
convert_record_value_to_int :: proc(recordValue: string) -> (int, ^lib.Error) {
    using lib

	value, intParseOk := strconv.parse_int(recordValue)
	if intParseOk {
		return value, no_error()
	} else {
		return -1, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_INTEGER, get_caller_location())
	}
}

@(require_results)
covert_record_to_float :: proc(recordValue: string) -> (f64, ^lib.Error) {
    using lib

	value, floatParseOk := strconv.parse_f64(recordValue)
	if floatParseOk {
		return value, no_error()
	} else {
		return -1.0,  make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_FLOAT, get_caller_location())
	}
}

@(require_results)
convert_record_value_to_bool :: proc(recordValue: string) -> (bool, ^lib.Error) {
    using lib

	valueLower := strings.to_lower(strings.trim_space(recordValue))

	if valueLower == "true" || valueLower == "t" {  //This remnant from the OstrichCLI allowed a user to set a record value to t or f and it would be assigned true or false
		return true, no_error()
	} else if valueLower == "false" || valueLower == "f" {
		return false, no_error()
	} else {
		//no need to do anything other than return here. Once false is returned error handling system will do its thing
		return false, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_BOOLEAN, get_caller_location())
	}
}

@(require_results)
convert_record_value_to_date :: proc(recordValue: string) -> (string, ^lib.Error) {
    using lib

	dateValue, dateParseOk := parse_date(recordValue)
	if dateParseOk == nil {
		return dateValue, no_error()
	}

	return get_err_msg(.DATA_CONVERSION_CANNOT_CONVERT_TO_DATE), make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_DATE, get_caller_location())
}

@(require_results)
convert_record_value_to_time :: proc(recordValue: string) -> (string, ^lib.Error) {
    using lib

	timeValue, timeParseOk := parse_time(recordValue)
	if timeParseOk == nil {
		return timeValue, no_error()
	}

	return get_err_msg(.DATA_CONVERSION_CANNOT_CONVERT_TO_TIME), make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_TIME, get_caller_location())
}

//example: 2023-08-20T12:34:56
@(require_results)
convert_record_value_to_datetime :: proc(recordValue: string) -> (string, ^lib.Error) {
    using lib

	datetimeValue, datetimeParseOk := parse_datetime(recordValue)
	if datetimeParseOk == nil {
		return datetimeValue, no_error()
	}

	return get_err_msg(.DATA_CONVERSION_CANNOT_CONVERT_TO_DATETIME), make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_DATETIME, get_caller_location())
}

@(require_results)
convert_record_value_to_uuid :: proc(recordValue: string) -> (string, ^lib.Error) {
    using lib

	uuidValue, uuidParseOk := parse_uuid(recordValue)
	if uuidParseOk == nil {
		return uuidValue, no_error()
	}

	return get_err_msg(.DATA_CONVERSION_CANNOT_CONVERT_TO_UUID), make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_UUID, get_caller_location())
}


@(require_results)
convert_record_value_to_int_array :: proc(recordValue: string) -> ([dynamic]int, ^lib.Error) {
    using lib

	newIntArray := make([dynamic]int)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil {
	      return newIntArray, parseError
	}
	for element in parsedArray {
		value, ok := strconv.parse_int(element)
		if ok{
		    append(&newIntArray, value)
		}else{
		    return newIntArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_INT_ARRAY, get_caller_location())
		}
	}

	return newIntArray, no_error()
}


@(require_results)
convert_record_value_to_float_array :: proc(recordValue: string) -> ([dynamic]f64, ^lib.Error) {
    using lib

	newFloatArray := make([dynamic]f64)
	parsedArray, parseError:= parse_array(recordValue)
	if parseError != nil{
	    return newFloatArray, parseError
	}
	for element in parsedArray {
		value, ok := strconv.parse_f64(element)
		if ok{
		    append(&newFloatArray, value)
		}else{
		    return newFloatArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_FLT_ARRAY, get_caller_location())
		}
	}

	return newFloatArray, no_error()
}


@(require_results)
convert_record_value_to_bool_array :: proc(recordValue: string) -> ([dynamic]bool, ^lib.Error) {
    using lib

	newBoolArray := make([dynamic]bool)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil {
	    return newBoolArray, parseError
	}
	for element in parsedArray {
		elementLower := strings.to_lower(strings.trim_space(element))

		if elementLower == "true" || elementLower == "t" {
			append(&newBoolArray, true)
		} else if elementLower == "false" || elementLower == "f" {
			append(&newBoolArray, false)
		} else {
			return newBoolArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_BOOL_ARRAY, get_caller_location())
		}
	}

	return newBoolArray, no_error()
}


@(require_results)
convert_record_value_to_string_array :: proc(recordValue: string) -> ([dynamic]string, ^lib.Error) {
    using lib

	newStringArray := make([dynamic]string)
	parsedArray ,parseError:= parse_array(recordValue)
	if parseError != nil{
	    return newStringArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_STR_ARRAY, get_caller_location())
	}
	for element in parsedArray {
		append(&newStringArray, element)
	}

	return newStringArray, no_error()
}


@(require_results)
convert_record_value_to_char_array :: proc(recordValue: string) -> ([dynamic]string, ^lib.Error) {
    using lib

	newCharArray := make([dynamic]string)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil{
	    return newCharArray, parseError
	}
	for element in parsedArray {
		append(&newCharArray, element)
	}

	return newCharArray, no_error()
}


@(require_results)
convert_record_value_to_date_array :: proc(recordValue: string) -> ([dynamic]string, ^lib.Error) {
    using lib

	newDateArray := make([dynamic]string)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil{
	    return newDateArray, parseError
	}
	for element in parsedArray {
		dateValue, dateParseOk := parse_date(element)
		if dateParseOk == nil {
			append(&newDateArray, dateValue)
		} else {
			return newDateArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_DATE_ARRAY, get_caller_location())
		}
	}

	return newDateArray, no_error()
}


@(require_results)
convert_record_value_to_time_array :: proc(recordValue: string) -> ([dynamic]string, ^lib.Error) {
    using lib

	newTimeArray := make([dynamic]string)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil{
	    return newTimeArray, parseError
	}
	for element in parsedArray {
		timeValue, timeParseOk := parse_time(element)
		if timeParseOk == nil {
			append(&newTimeArray, timeValue)
		} else {
			return newTimeArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_TIME_ARRAY, get_caller_location())
		}
	}

	return newTimeArray, no_error()
}


@(require_results)
convert_record_value_to_datetime_array :: proc(recordValue: string) -> ([dynamic]string, ^lib.Error) {
    using lib

	newDateTimeArray := make([dynamic]string)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil{
	    return newDateTimeArray, parseError
	}
	for element in parsedArray {
		datetimeValue, datetimeParseOk := parse_datetime(element)
		if datetimeParseOk  == nil{
			append(&newDateTimeArray, datetimeValue)
		} else {
			return newDateTimeArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_DT_ARRAY, get_caller_location())
		}
	}

	return newDateTimeArray, no_error()
}


@(require_results)
convert_record_value_to_uuid_array :: proc(recordValue: string) -> ([dynamic]string, ^lib.Error) {
    using lib

	newUUIDArray := make([dynamic]string)
	parsedArray, parseError := parse_array(recordValue)
	if parseError != nil{
        return newUUIDArray, parseError
	}
	for element in parsedArray {
		uuidValue, uuidParseOk := parse_uuid(element)
		if uuidParseOk  == nil{
			append(&newUUIDArray, uuidValue)
		} else {
			return newUUIDArray, make_new_err(.DATA_CONVERSION_CANNOT_CONVERT_TO_UUID_ARRAY, get_caller_location())
		}
	}

	return newUUIDArray, no_error()
}


//Handles the conversion of a record value from the old type to a new type
//this could also go into the records.odin file but will leave it here for now
@(require_results)
convert_record_value_with_type_change :: proc(value, oldT, newT: string) -> (string, ^lib.Error) {
    using lib


    if len(value) == 0 {
		return get_err_msg(.DATA_CONVERSION_WITH_TYPE_CHANGE), make_new_err(.DATA_CONVERSION_WITH_TYPE_CHANGE, get_caller_location())
	}

	oldValueIsArray := strings.has_prefix(oldT, "[]")
	newValueIsArray := strings.has_prefix(newT, "[]")

	//handle array conversion
	if oldValueIsArray && newValueIsArray {
		parsedArray, parseError := parse_array(value)
		if parseError != nil{
            return get_err_msg(.DATA_CONVERSION_WITH_TYPE_CHANGE), parseError
		}
		newArray := make([dynamic]string)
		defer delete(newArray)

		for element in parsedArray {
			convertedValue, conversionSuccess := convert_primitive_value(element, oldT, newT) //convert the value
			if conversionSuccess != nil{
				return get_err_msg(.DATA_CONVERSION_WITH_TYPE_CHANGE), make_new_err(.DATA_CONVERSION_WITH_TYPE_CHANGE, get_caller_location())
			}else{
			    append(&newArray, convertedValue) //append the converted value to the new array
			}
		}

		return strings.join(newArray[:], ","), no_error()
	}

	//handle single value conversion
	if !oldValueIsArray && newValueIsArray { 	//if the old value is not an array and the new value is
		convertedValue, coversionSuccess := convert_primitive_value(value, oldT, newT) //convert the single value
		if coversionSuccess != nil{
		    return get_err_msg(.DATA_CONVERSION_WITH_TYPE_CHANGE), make_new_err(.DATA_CONVERSION_WITH_TYPE_CHANGE, get_caller_location())
		}

		return convertedValue, no_error()
	}

	//handle array to single value conversion
	if oldValueIsArray && !newValueIsArray { 	//if the old value is an array and the new value is not
		parsedArray, parseError := parse_array(value) //parse the array
		if parseError != nil{
		    return value, parseError
		}
		if len(parsedArray) > 0 { 	//if there are parsedArray in the array
		    firstValue := lib.strip_array_brackets(parsedArray[0])
			convertedValue, conversionSuccess:= convert_primitive_value(firstValue, oldT, newT)
			if conversionSuccess != nil{
			    return get_err_msg(.DATA_CONVERSION_WITH_TYPE_CHANGE), make_new_err(.DATA_CONVERSION_WITH_TYPE_CHANGE, get_caller_location())
			}
			return convertedValue, no_error()
		}
	}

	//if the old and new value are both single values
	convertedValue, conversionSuccess:=convert_primitive_value(value, oldT, newT)
	if conversionSuccess != nil{
	    return get_err_msg(.DATA_CONVERSION_WITH_TYPE_CHANGE), make_new_err(.DATA_CONVERSION_WITH_TYPE_CHANGE, get_caller_location())
	}

	return convertedValue, no_error()
}


//Used to convert a single record value to a different value depending on the new type provided.
//e.g if converting an int: 123 to a string then it will return "123"
@(require_results)
convert_primitive_value :: proc(value: string, oldType: string, newType: string) -> (string, ^lib.Error) {
	using lib
	using fmt

	//if the types are the same, no conversion is needed
	if oldType == newType {
		return value, make_new_err(.DATA_CONVERSION_TYPES_MATCH, get_caller_location())
	}

	switch (newType) {
	case RecordDataTypesStrings[.STRING]:
		//New type is STRING
		switch (oldType) {
		case RecordDataTypesStrings[.INTEGER], RecordDataTypesStrings[.FLOAT], RecordDataTypesStrings[.BOOLEAN]:
			//Old type is INTEGER, FLOAT, or BOOLEAN
			quotedValue := append_qoutations(value)
			return quotedValue, no_error()
		case RecordDataTypesStrings[.STRING_ARRAY]:
			newValue := strip_array_brackets(value)
			if len(newValue) > 0 {
				quotedValue := append_qoutations(newValue)
				return quotedValue, no_error()
			}
			return "\"\"", no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	case RecordDataTypesStrings[.INTEGER]:
		//New type is INTEGER
		switch (oldType) {
		case RecordDataTypesStrings[.STRING]:
			//Old type is STRING
			_, intParseOK := strconv.parse_int(value, 10)
			if !intParseOK {
				return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
			}
			return value, no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	case RecordDataTypesStrings[.FLOAT]:
		//New type is FLOAT
		switch (oldType) {
		case RecordDataTypesStrings[.STRING]:
			//Old type is STRING
			_, floatParseOk := strconv.parse_f64(value)
			if !floatParseOk {
				return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
			}
			return value, no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	case RecordDataTypesStrings[.BOOLEAN]:
		//New type is BOOLEAN
		switch (oldType) {
		case RecordDataTypesStrings[.STRING]:
			//Old type is STRING
			lowerStr := strings.to_lower(strings.trim_space(value))
			if lowerStr == "true" || lowerStr == "false" {
				return lowerStr, no_error()
			}
			return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	//ARRAY CONVERSIONS
	case RecordDataTypesStrings[.STRING_ARRAY]:
		// New type is STRING_ARRAY
		switch (oldType) {
		case RecordDataTypesStrings[.STRING]:
			// Remove any existing quotes
			unquotedValue := strings.trim_prefix(strings.trim_suffix(value, "\""), "\"")
			// Format as array with proper quotes
			return fmt.tprintf("[\"%s\"]", unquotedValue), no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	case RecordDataTypesStrings[.INTEGER_ARRAY]:
		// New type is INTEGER_ARRAY
		switch (oldType) {
		case RecordDataTypesStrings[.INTEGER]:
			// Format as array
			return tprintf("[%s]", value), no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	case RecordDataTypesStrings[.BOOLEAN_ARRAY]:
		// New type is BOOLEAN_ARRAY
		switch (oldType) {
		case RecordDataTypesStrings[.BOOLEAN]:
			// Format as array
			return tprintf("[%s]", value), no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	case RecordDataTypesStrings[.FLOAT_ARRAY]:
		// New type is FLOAT_ARRAY
		switch (oldType) {
		case RecordDataTypesStrings[.FLOAT]:
			// Format as array
			return tprintf("[%s]", value), no_error()
		case:
			return "Unknown Conversion Error", make_new_err(.UNKNOWN, get_caller_location())
		}
	}

	return "CRITICAL UNKOWN CONVERSION ERROR", make_new_err(.UNKNOWN, get_caller_location())
}


//The only proc in this file that actually physically causes a change in a collection
//handles a records type and value change
@(require_results)
convert_record_value_type_then_update :: proc(projectContext: ^lib.ProjectContext,collection: ^lib.Collection,cluster:^lib.Cluster, record:^lib.Record, newType: string) -> ^lib.Error {
	using lib

	oldType, getRecordTypeSuccess := get_record_type(projectContext, collection, cluster, record)
	if getRecordTypeSuccess != nil{
	    return getRecordTypeSuccess
	}

	recordValue, getRecordValueSuccess := get_record_value(projectContext, collection, cluster, record)
	if getRecordValueSuccess!= nil{
	    return getRecordValueSuccess
	}


	newRecordValue, conversionSuccess := convert_record_value_with_type_change(recordValue, oldType, newType)
	if conversionSuccess != nil{
		return conversionSuccess
	} else {
		typeChangeSucess := update_record_data_type(projectContext, collection, cluster, record , newType)
		valueChangeSuccess := update_record_value(projectContext, collection, cluster, record, newRecordValue) //might need to use set_record_value() but that would requir refactor of that proc to accept new arg
		if typeChangeSucess != nil || valueChangeSuccess != nil {
			return valueChangeSuccess
		} else if typeChangeSucess == nil && valueChangeSuccess  == nil{
		    return no_error()
		}
	}

	return make_new_err(.RECORD_CONVERT_TYPE, get_caller_location())
}


//This proc formats array values based on their type:
//- For []CHAR arrays: Replaces double quotes with single quotes
//- For []DATE, []TIME, []DATETIME arrays: Removes quotes entirely
//Dont forget to free the memory in the calling procedure
@(require_results)
format_array_values_by_type :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster, record: ^lib.Record) -> (string, ^lib.Error) {
	using lib
	using fmt

	recordValue, getRecordSuccess := get_record_value(projectContext, collection, cluster, record)
	if  recordValue == "" || getRecordSuccess != nil{
		return get_err_msg(.COMPLEX_CANNOT_FORMAT_ARRAY), make_new_err(.COMPLEX_CANNOT_FORMAT_ARRAY, get_caller_location())
	}

	// Remove the outer brackets
	value := strings.trim_space(recordValue)

	if !strings.has_prefix(value, "[") || !strings.has_suffix(value, "]") {
		return get_err_msg(.COMPLEX_CANNOT_FORMAT_ARRAY), make_new_err(.COMPLEX_CANNOT_FORMAT_ARRAY, get_caller_location())
	}

	value = value[1:len(value) - 1]

	// Split the array elements
	elements := strings.split(value, ",")

	// Create a new array to store modified values
	modifiedElements := make([dynamic]string)
	defer delete(modifiedElements)

	// Process each element based on type
	for element in elements {
		element := strings.trim_space(element)

		#partial switch record.type {
		case .CHAR_ARRAY:
			// Replace double quotes with single quotes
			if strings.has_prefix(element, "\"") && strings.has_suffix(element, "\"") {
				element = tprintf("'%s'", element[1:len(element) - 1])
			}
		case .DATE_ARRAY, .TIME_ARRAY, .DATETIME_ARRAY, .UUID_ARRAY:
			// Remove quotes entirely
			if strings.has_prefix(element, "\"") && strings.has_suffix(element, "\"") {
				element = element[1:len(element) - 1]
			}
		}
		append(&modifiedElements, element)
	}

	// Join the modified elements back into an array string
	result := tprintf("[%s]", strings.join(modifiedElements[:], ", "))

	// Update the record with the modified value
	updateRecordSuccess := update_record_value(projectContext, collection, cluster, record, result)
	if updateRecordSuccess != nil{
	    return get_err_msg(.COMPLEX_CANNOT_FORMAT_ARRAY), updateRecordSuccess
	}

	return result, no_error()
}