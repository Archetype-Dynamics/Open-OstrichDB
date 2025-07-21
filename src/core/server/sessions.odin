package server

import "core:time"
import "core:math/rand"
import lib"../../library"
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
            Contains logic for server session information tracking
*********************************************************/

//Ceate and return a new server session, sets default session info. takes in the current user
@(cold, require_results)
make_new_server_session ::proc() -> ^lib.ServerSession{
    using lib
    newSession := new(ServerSession)
	newSession.Id  = rand.int63_max(1e16 + 1)
    newSession.start_timestamp = time.now()
    //newSession.end_timestamp is set when the kill switch is activated or server loop ends
    // newSession.user = user^

    // free(user)
    return newSession
}