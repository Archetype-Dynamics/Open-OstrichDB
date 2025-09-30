package data

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:unicode/utf8"
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
            Contains logic for how OstrichDB handles'complex' data types.
            e.g dates, times, arrays, etc...
*********************************************************/


//split the passed in "array" which is actually a string from whatever input system is in place(e.g the in the OstrichDB CLI the usesr input would be passed)
@(require_results)
parse_array :: proc(arrayAsString:string) -> ([]string, ^lib.Error) {
    using lib

    result := strings.split(arrayAsString, ",")
    return result, no_error()
}

//verifies that the members of the passed in array are valid based on the type of array they are in
@(require_results)
verify_array_values :: proc(record: ^lib.Record) -> ^lib.Error {
	using lib

	verified := false
	//retrieve the record type
	parsedArray, parseError := parse_array(record.value)
	if parseError != nil{
	    return parseError
	}

	#partial switch (record.type) {
	case .INTEGER_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := strconv.parse_int(element)
			if !parseSuccess {
				verified = false
				break
			}
		}
		break
	case .FLOAT_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := strconv.parse_f64(element)
			if !parseSuccess {
				verified = false
				break
			}
		}
		break
	case .BOOLEAN_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := strconv.parse_bool(element)
			if !parseSuccess {
				verified = false
				break
			}
		}
		break
	case .DATE_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := parse_date(element)
			if parseSuccess != nil{
			    verified = false
			    break
			}
		}
		break
	case .TIME_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := parse_time(element)
			if parseSuccess != nil{
			    verified = false
			    break
			}
		}
		break
	case .DATETIME_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := parse_datetime(element)
			if parseSuccess != nil{
			    verified = false
			    break
			}
		}
		break
	case .STRING_ARRAY, .CHAR_ARRAY:
		verified = true
		break
	case .UUID_ARRAY:
		verified = true
		for element in parsedArray {
			_, parseSuccess := parse_uuid(element)
			if parseSuccess != nil{
			    verified = false
			    break
			}
		}
		 break
	}

	if !verified{
	    return make_new_err(.COMPLEX_CANNOT_VERIFY_ARRAY_VALUES, get_caller_location())
	}

	return no_error()
}


//validates the passed in date and returns it
//remember to delete return value in from calling procedure
@(require_results)
parse_date :: proc(date: string) -> (string, ^lib.Error) {
    using lib
    using fmt

	dateString := ""

	parts := strings.split(date, "-")
	if len(parts) != 3 {
	    return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}

	//check length requirments
	if len(parts[0]) != 4 || len(parts[1]) != 2 || len(parts[2]) != 2 {
		return get_err_msg(.COMPLEX_INVALID_DATE_LENGTH), make_new_err(.COMPLEX_INVALID_DATE_LENGTH, get_caller_location())
	}

	year, yearParsedOk := strconv.parse_int(parts[0])
	month, monthParsedOk := strconv.parse_int(parts[1])
	day, dayParsedOk := strconv.parse_int(parts[2])

	if !yearParsedOk || !monthParsedOk || !dayParsedOk {
		return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}

	//validate month range
	if month < 1 || month > 12 {
		return get_err_msg(.COMPLEX_INVALID_DATE_FORMAT), make_new_err(.COMPLEX_INVALID_DATE_FORMAT, get_caller_location())
	}

	//Calculate days in month
	daysInMonth := 31
	switch month {
	    case 4, 6, 9, 11:
			daysInMonth = 30
			break
		case 2:
		    // Leap year calculation
		    isLeapYear := (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
		    daysInMonth = isLeapYear ? 29 : 28
		    break
	}

	// Validate day range
	if day < 1 || day > daysInMonth {
		return get_err_msg(.COMPLEX_INVALID_DATE_FORMAT), make_new_err(.COMPLEX_INVALID_DATE_FORMAT, get_caller_location())
	}


	// Format with leading zeros
	monthString := tprintf("%02d", month)
	dayString := tprintf("%02d", day)
	yearString := tprintf("%04d", year)
	dateString = tprintf("%s-%s-%s", yearString, monthString, dayString)

	return strings.clone(dateString), no_error()
}

//validates the passed in time and returns it
//remember to delete return value in from calling procedure
@(require_results)
parse_time :: proc(time: string) -> (string, ^lib.Error) {
    using lib
    using fmt

	timeString := ""

	parts := strings.split(time, ":")
	if len(parts) != 3 {
	    return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}

	if len(parts[0]) != 2 || len(parts[1]) != 2 || len(parts[2]) != 2 {
		return get_err_msg(.COMPLEX_INVALID_TIME_LENGTH),  make_new_err(.COMPLEX_INVALID_TIME_LENGTH, get_caller_location())
	}

	// Convert strings to integers for validation
	hour, hourParsedOk := strconv.parse_int(parts[0])
	minute, minuteParsedOk := strconv.parse_int(parts[1])
	second, secondParsedOk := strconv.parse_int(parts[2])

	if !hourParsedOk || !minuteParsedOk || !secondParsedOk {
		return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}

	// Validate ranges
	if hour < 0 || hour > MAX_HOURS {
		return get_err_msg(.COMPLEX_INVALID_TIME_FORMAT), make_new_err(.COMPLEX_INVALID_TIME_FORMAT, get_caller_location())
	}
	if minute < 0 || minute > MAX_MINUTES {
		return get_err_msg(.COMPLEX_INVALID_TIME_FORMAT), make_new_err(.COMPLEX_INVALID_TIME_FORMAT, get_caller_location())
	}
	if second < 0 || second > MAX_SECONDS {
		return get_err_msg(.COMPLEX_INVALID_TIME_FORMAT), make_new_err(.COMPLEX_INVALID_TIME_FORMAT, get_caller_location())
	}

	// Format with leading zeros
	timeString = tprintf("%02d:%02d:%02d", hour, minute, second)

	return strings.clone(timeString), no_error()
}

//validates the passed in datetime and returns it
//Example datetime: 2024-03-14T09:30:00
//remember to delete return value in from calling procedure
@(require_results)
parse_datetime :: proc(dateTime: string) -> (string, ^lib.Error) {
    using lib
    using fmt

    dateTimeArr := strings.split(dateTime, "T")
    if len(dateTimeArr) != 2 {
        return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
    }

	dateString, dateParseSuccess := parse_date(dateTimeArr[0])
	if dateParseSuccess != nil{
	    return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}

	timeString, timeParseSuccess := parse_time(dateTimeArr[1])
	if timeParseSuccess != nil{
		return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}

	dateTimeString := tprintf("%sT%s", dateString, timeString)

	return strings.clone(dateTimeString), no_error()
}


//parses the passed in string ensuring proper format and length
//Must be in the format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
//Only allows 0-9 and a-f
//remember to delete return value in from calling procedure
@(require_results)
parse_uuid :: proc(uuid: string) -> (string, ^lib.Error) {
    using lib
    using fmt

	isValidChar := false
	uuidString := ""

	possibleChars: []string = {
		"0",
		"1",
		"2",
		"3",
		"4",
		"5",
		"6",
		"7",
		"8",
		"9",
		"a",
		"b",
		"c",
		"d",
		"e",
		"f",
	}

	parts := strings.split(uuid, "-")
	if len(parts) != 5 {
        return get_err_msg(.COMPLEX_CANNOT_PARSE_DATA), make_new_err(.COMPLEX_CANNOT_PARSE_DATA, get_caller_location())
	}


	if len(parts[0]) != 8 ||
	   len(parts[1]) != 4 ||
	   len(parts[2]) != 4 ||
	   len(parts[3]) != 4 ||
	   len(parts[4]) != 12 {
		return get_err_msg(.COMPLEX_INVALID_UUID_LENGTH), make_new_err(.COMPLEX_INVALID_UUID_LENGTH, get_caller_location())
	}

	// Validate each section of the UUID
	for section in parts {
		for value in section {
			// Convert the rune to a lowercase string
			runeArr := make([]rune, 1)
			defer delete(runeArr)

			runeArr[0] = value
			charLower := strings.to_lower(utf8.runes_to_string(runeArr)) //convert the Odin rune to a string so it can be returned
			isValidChar = false

			// Check if the character is in the allowed set
			for char in possibleChars {
				if charLower == char {
					isValidChar = true
					break
				}
			}

			if !isValidChar {
				return get_err_msg(.COMPLEX_INVALID_UUID_FORMAT), make_new_err(.COMPLEX_INVALID_UUID_FORMAT, get_caller_location())
			}
		}
	}

	uuidString = fmt.tprintf(
		"%s-%s-%s-%s-%s",
		parts[0],
		parts[1],
		parts[2],
		parts[3],
		parts[4],
	)
	uuidString = strings.to_lower(uuidString)

	return strings.clone(uuidString), no_error()
}
