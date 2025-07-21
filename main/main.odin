package main

import "core:fmt"
import lib"../src/library"
import "../src/core/engine"
import "../src/core/config"
import "../src/core/engine/projects"
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
            Main entry point
*********************************************************/

main ::proc (){
    using lib
    using config
    using engine


    //Uncomment if testing things out
    // create_test_user()
    // test_project_creation()
    engine.start_engine()
}

// Uncomment if first time setting up
// create_test_user :: proc() -> bool {
//     using lib
//     using config

//     // Initialize paths
//     pathConfig := init_dynamic_paths("development")
//     defer cleanup_dynamic_paths()

//     testUserID := "test_user_12345"

//     // Create user directory structure
//     return create_user_directory_structure(testUserID)
// }

// Uncomment if first time setting up
// test_project_creation :: proc() -> bool {
//     using projects

//     testUserID := "test_user_12345"
//     testProjectName := "my-test-project"

//     projectContext := make_new_project_context(testUserID, testProjectName)
//     defer free(projectContext)

//     return init_project_structure(projectContext)
// }