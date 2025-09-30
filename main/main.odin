package main

import "core:fmt"
import lib"../src/library"
import "../src/core/server"
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
            Main entry point
*********************************************************/

//Not much to see here :)
main ::proc () {
    using lib
    using server

    for {
        engine := new(OstrichDBEngine)
        server:= new(Server)
        defer free(engine)
        defer free (server)

        run_ostrich_server(server)
    }
}
