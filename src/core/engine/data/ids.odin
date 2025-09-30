package data

import "core:fmt"
import "core:strings"
import "core:math/rand"
import "../data"
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
            This file contains all the logic handling record, cluster and user IDs
*********************************************************/


increment_record_id :: proc(projectContext: ^lib.ProjectContext, collection: ^lib.Collection, cluster: ^lib.Cluster)-> (i64, ^lib.Error){
    using lib
    using data

    currentRecordCount, error := get_record_count_within_cluster(projectContext, collection, cluster)
    if error != nil{
        return -1, error
    }
    currentRecordCount += 1

    return currentRecordCount, no_error()
}