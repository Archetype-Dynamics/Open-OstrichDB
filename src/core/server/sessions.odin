package server

import "core:time"
import "core:math/rand"
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