package queries

import "core:os"
import "core:fmt"
import "core:strings"
import "../users"
import lib"../../../library"

make_new_query :: proc(input:= "") -> (^lib.Query){
        query:= new(lib.Query)

        query.commandToken = nil
		query.locationToken   = make([dynamic]string)
		query.paramToken = make(map[string]string)
		query.targetToken = ""
		query.isChained = false
		query.rawInput = input

		return query
}

//breaks down a string input into a query then returns it
parse_query :: proc (input: string) -> (^lib.Query, ^lib.Error){
    using lib
    using strings


    //todo: this needs to be updated,
    // should see if '&&' is found at the end of a query, not just continained in a query
   	if strings.contains(input, "&&") {
		return parse_chained_query(input), no_error()
	}


    tokens := split(trim_space(input), " ")
    query:= make_new_query(input)



    if len(tokens) == 0 {
		return query, make_new_err(.QUERY_CANNOT_BE_EMPTY,get_caller_location())
	}

	if !check_if_token_is_valid(.COMMAND, to_upper(tokens[0])){
	    return query, make_new_err(.QUERY_INVALID_COMMAND_TOKEN, get_caller_location())
	}

	query.commandToken = convert_str_to_token(to_upper(tokens[0]))
	state:= QueryParserState.EXPECTING_PARAM_TOKEN
	currentParamToken:= ""
	isParsingValue:= false
	currentValue:= ""

	//start at 1 index since commandToken is auto set
	for i:= 1; i < len(tokens); i+= 1{
	    token := tokens[i]
		if isParsingValue{
		    if check_if_token_is_valid(.PARAM, to_upper(token)) {
			    query.paramToken[currentParamToken] = to_upper(currentValue)
			    currentParamToken = to_upper(token)
			    currentValue = ""
			    state = .EXPECTING_VALUE
			    continue
		    }
		    if len(currentValue) > 0{
		        currentValue = concatenate([]string{currentValue, " ", token})
		    } else{
		        currentValue = token
			}
		     continue
		}

		#partial switch(state){
            case .EXPECTING_PARAM_TOKEN:
                if check_if_token_is_valid(.PARAM, to_upper(token)) {
                    currentParamToken = to_upper(token)
                    state = .EXPECTING_VALUE
                } //else do return query, make_new_err(.QUERY_INVALID_PARAM_TOKEN, get_caller_location())
                append(&query.locationToken, token)  // <----This is NOT apart of the 'do return' directly above
            case .EXPECTING_VALUE:
                currentValue = token
                isParsingValue = true
		}
	}

	if isParsingValue && len(currentValue) > 0 {
	    query.paramToken[currentParamToken] = currentValue
		// If the current parameter token is OF_TYPE and the query.commandToken is NEW
			// Check if the string value contains the WITH token to handle record values
			if convert_str_to_token(to_upper(currentParamToken))== .OF_TYPE && query.commandToken == .NEW {
				// Split the string to check for WITH token
				parts := strings.split(currentValue, " ")
				if len(parts) >= 2 && to_upper(parts[1]) == TokenStr[.WITH] {
					// Store the type in` the OF_TYPE map value slot
					query.paramToken[currentParamToken] = to_upper(parts[0])
					// Store everything after the WITH token in the WITH map value slot
					if len(parts) > 2 {
						withValue := join(parts[2:], " ")
						query.paramToken[TokenStr[.WITH]] = to_upper(withValue)
					} else {
						// Handle case where WITH is the last token with no value
						query.paramToken[TokenStr[.WITH]] = ""
					}
				}
			}
		}

	  return query, no_error()
}


//Helper proc for parsing chained commands, helps clean up the main parser proc above
@(require_results)
parse_chained_query :: proc(input: string) -> ^lib.Query {
    using lib
    using strings

    query:= make_new_query(input)

    parts := split(input, "&&")
    if len(parts) > 0 {
        firstQuery := trim_space(parts[0])
        firstTokens := split(trim_space(firstQuery), " ")
        if len(firstTokens) > 0 {
            query.commandToken = convert_str_to_token(to_upper(firstTokens[0]))
        }
    }

    return query
}

//checks if a token is a valid based on the passed in token type
@(require_results)
check_if_token_is_valid :: proc(tokenType: lib.TokenType, token:string)-> bool{
    using lib

    validTokens: []string

    #partial switch(tokenType){
        case .COMMAND:
            validTokens = {"NEW", "RENAME", "ERASE", "DELETE",  "FETCH", "SET"}
            for cmdToken in validTokens {
                if strings.to_upper(token) == cmdToken do return true
            }
            break
        case .PARAM:
            validTokens = {"WITH", "TO", "OF_TYPE"}
           	for paramToken in validTokens {
                if strings.to_upper(token) == paramToken do return true
            }
            break
    }

    return false
}

@(require_results)
convert_str_to_token :: proc(str: string)-> lib.Token {
    using lib

    for tokenStr, index in lib.TokenStr {
        if str == tokenStr {
            return index
        }
    }
	return Token.INVALID
}


//takes the passed query and constructs a valid http endpoint
query_to_endpoint_constructor ::proc(projCTX: ^lib.ProjectContext, Q: ^lib.Query) -> string{
    using lib
    using strings

    collectionName, clusterName, recordName: string
    containsCluster, containsRecord: bool
    locationArray:= make([dynamic]string)

    if contains(Q.locationToken[0], "."){
        locationSplit:= strings.split(Q.locationToken[0], ".")
        for loc in locationSplit{
            append(&locationArray, loc)
        }
    }else{
        append(&locationArray, Q.locationToken[0])
    }

    switch(len(locationArray)){
        case 1:
            collectionName = locationArray[0]
            break
        case 2:
            collectionName = locationArray[0]
            clusterName = locationArray[1]
            break
        case 3:
            collectionName = locationArray[0]
            clusterName = locationArray[1]
            recordName = locationArray[2]
            break
    }

    path: strings.Builder = strings.builder_make()
    projName:= projCTX.projectName

    //build a path in the format: api/v1/projects/{projName}/collections/{locToken[0]/clusters/.....}
    write_string(&path, "api/v1/",)
    write_string(&path, "projects/")
    write_string(&path, fmt.tprintf("%s/", projName))
    write_string(&path, "collections/")
    if len(locationArray) > 0 && len(locationArray) < 4 {
        write_string(&path, collectionName) //collection name
        if  len(locationArray) == 1 && len(Q.paramToken) == 1 { //In the event we are renaming a Collection using the  'TO' token
            write_string(&path, "?")
            write_string(&path, "rename=")
            for key, val in Q.paramToken{
                write_string(&path, val)
                break
            }
        }
        if len(locationArray) == 2 || len(locationArray) == 3   { //path contains a Cluster
            write_string(&path, "/")
            write_string(&path, "clusters/")
            write_string(&path, clusterName,) //cluster name
            if len(locationArray) == 2 &&  len(Q.paramToken) == 1{ //in the event renaming a Cluster
                write_string(&path, "?")
                write_string(&path, "rename=")
                for key, val in Q.paramToken{
                    write_string(&path, val)
                    break
                }
            }
            if len(locationArray) == 3{ //path contains a Record
                write_string(&path, "/")
                write_string(&path, "records/")
                write_string(&path, recordName) //Record name
                if len(Q.paramToken) > 0 {
                    write_string(&path, "?")
                }
               #partial switch(Q.commandToken){ //records can have their name, type and value updated so logic handle differently here - Marshall
                    case .NEW:
                        recordType, recordValue: string
                        fmt.println("Q.paramToken: ", Q.paramToken)
                        write_string(&path,  "type=")
                        recordType = Q.paramToken["OF_TYPE"]
                        write_string(&path, recordType)
                        recordValue = Q.paramToken["WITH"]
                        write_string(&path, "&value=")
                        write_string(&path, recordValue)
                        break
                    case .RENAME:
                        write_string(&path, "rename=")
                        for _, val in Q.paramToken{
                            write_string(&path, val)
                            break
                        }
                        break
                    case .CHANGE_TYPE:
                        write_string(&path,  "type=")
                        for _, val in Q.paramToken{
                            write_string(&path, val)
                        }
                        break
                    case .SET:
                        write_string(&path, "value=")
                        for _, val in Q.paramToken {
                            write_string(&path, val)
                        }
                        break
                    }
                }
            }
        }

    delete(locationArray)
    fmt.println(to_string(path))

    return to_string(path)
}




