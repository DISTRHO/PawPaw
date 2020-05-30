#!/bin/bash

set -e

# common
sudo apt-get install -y build-essential coreutils curl cmake jq

# for cross-compilation
if [ "${TARGET}" = "macos-old" ]; then
    sudo apt-get install -y apple-x86-gcc apple-uni-sdk-10.5

elif [ "${TARGET}" = "win32" ]; then
    sudo apt-get install -y mingw32-x-gcc

elif [ "${TARGET}" = "win64" ]; then
    sudo apt-get install -y mingw64-x-gcc

fi
