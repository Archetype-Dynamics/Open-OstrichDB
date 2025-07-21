package engine
import "../server"
import lib "../../library"
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
            Contains logic for the OstrichDB engine
*********************************************************/

//The OstrichDB engine requires the server to be running
start_engine ::proc() -> ^lib.Error {
    using lib
    using server

    result: ^Error
    for {
        engine := new(OstrichDBEngine)
        defer free(engine)
        server:= new(Server)
        defer free (server)

        result = start_ostrich_server(server)
    }

    return result
}