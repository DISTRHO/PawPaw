#!/bin/bash

set -e

# common
sudo apt-get install -y build-essential curl cmake jq

# for cross-compilation
if [ "${TARGET}" = "macos-old" ]; then
    sudo apt-get install -y apple-x86-gcc apple-uni-sdk-10.5

elif [ "${TARGET}" = "win32" ]; then
    sudo apt-get install -y mingw-w64 binutils-mingw-w64-i686 g++-mingw-w64-i686

elif [ "${TARGET}" = "win64" ]; then
    sudo apt-get install -y mingw-w64 binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64

fi
