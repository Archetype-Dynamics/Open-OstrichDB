#!/bin/bash
# Copyright (c) 2025-Present Marshall A Burns and Archetype Dynamics, Inc.
# SPDX-License-Identifier: BSL-1.1

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to the project root directory
cd "$DIR/.."

OS_TYPE="$(uname)"
case "$OS_TYPE" in
    "Linux")
        LIB_EXT="so"
        ;;
    "Darwin")
        LIB_EXT="dylib"
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE"
        exit 1
        ;;
esac

odin build main

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build successful"

    # Create bin directory if it doesn't exist
    mkdir -p ./bin


    # Try to move the executable
    if mv main.bin ./bin/ 2>/dev/null; then
        echo "Executable moved to bin directory"
        # Change directory to bin before running
        cd bin
    else
        echo "Could not move executable to bin directory"
        exit 1
    fi

    # pwd
    # ls
    # Run the program from the bin directory
    ./main.bin

    # Return to the project root directory
    cd "$DIR/.."
else
    echo "Build failed"
    exit 1
fi