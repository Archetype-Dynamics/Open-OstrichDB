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