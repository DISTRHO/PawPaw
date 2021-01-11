#!/bin/bash

CROSS_COMPILING=0
LINUX=0
MACOS=0
MACOS_OLD=0
MACOS_UNIVERSAL=0
WIN32=0
WIN64=0

function check_target() {
    case "${target}" in
        "macos"|"Darwin")
            MACOS=1
            ;;
        "macos-old")
            MACOS=1
            MACOS_OLD=1
            CROSS_COMPILING=1
            ;;
        "macos-universal")
            MACOS=1
            MACOS_UNIVERSAL=1
            ;;
        "win32"|"MINGW32"*)
            WIN32=1
            CROSS_COMPILING=1
            if [ "$(uname -o)" != "Msys" ] && [ "$(uname -o)" != "Cygwin" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "win64"|"MINGW64"*)
            WIN32=1
            WIN64=1
            if [ "$(uname -o)" != "Msys" ] && [ "$(uname -o)" != "Cygwin" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "linux"|"Linux")
            LINUX=1
            ;;
        "native")
            target=$(uname -s)
            check_target
            if [ "${target}" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
                MACOS_UNIVERSAL=1
            fi
            ;;
        default)
            echo "Invalid target '${target}', possible values are:"
            echo "\tmacos"
            echo "\tmacos-old"
            echo "\tmacos-universal"
            echo "\twin32"
            echo "\twin64"
            echo "\tnative"
            if [ -z "${VALIDATE_TARGET}" ]; then
                exit 2
            else
                INVALID_TARGET=1
            fi
            ;;
    esac
}

check_target
