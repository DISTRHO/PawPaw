#!/bin/bash

CROSS_COMPILING=0
LINUX=0
MACOS=0
MACOS_OLD=0
WIN32=0
WIN64=0

function check_target() {
    case "${target}" in
        "macos")
            MACOS=1
            ;;
        "macos-old")
            MACOS=1
            MACOS_OLD=1
            CROSS_COMPILING=1
            ;;
        "win32")
            WIN32=1
            CROSS_COMPILING=1
            ;;
        "win64")
            WIN32=1
            WIN64=1
            CROSS_COMPILING=1
            ;;
        "Linux")
            LINUX=1
            ;;
        "native")
            target=$(uname -s)
            check_target
            ;;
        default)
            echo "Invalid target '${target}', possible values are:"
            echo "\tmacos"
            echo "\tmacos-old"
            echo "\twin32"
            echo "\twin64"
            echo "\tnative"
            exit 2
            ;;
    esac
}

check_target
