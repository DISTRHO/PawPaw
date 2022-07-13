#!/bin/bash

CLANG=0
GCC=0

CROSS_COMPILING=0
INVALID_TARGET=0

LINUX=0
MACOS=0
MACOS_UNIVERSAL=0
WASM=0
WIN32=0
WIN64=0

function check_target() {
    case "${target}" in
        "macos"|"Darwin")
            CLANG=1
            MACOS=1
            PAWPAW_SKIP_FORTIFY=1
            ;;
        "macos-universal")
            CLANG=1
            MACOS=1
            MACOS_UNIVERSAL=1
            PAWPAW_SKIP_FORTIFY=1
            ;;
        "wasm")
            CLANG=1
            CROSS_COMPILING=1
            WASM=1
            PAWPAW_SKIP_FORTIFY=1
            PAWPAW_SKIP_LTO=1
            ;;
        "win32"|"MINGW32"*)
            GCC=1
            WIN32=1
            if [ "$(uname -o)" != "Msys" ] && [ "$(uname -o)" != "Cygwin" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "win64"|"MINGW64"*)
            GCC=1
            WIN32=1
            WIN64=1
            if [ "$(uname -o)" != "Msys" ] && [ "$(uname -o)" != "Cygwin" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "CYGWIN"*|"MSYS"*)
            GCC=1
            WIN32=1
            if [ "$(uname -m)" = "x86_64" ]; then
                WIN64=1
            fi
            ;;
        "linux"|"Linux")
            GCC=1
            LINUX=1
            ;;
        "linux-aarch64")
            GCC=1
            CROSS_COMPILING=1
            LINUX=1
            TOOLCHAIN_PREFIX="aarch64-linux-gnu"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            ;;
        "linux-armhf")
            GCC=1
            CROSS_COMPILING=1
            LINUX=1
            TOOLCHAIN_PREFIX="arm-linux-gnueabihf"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            ;;
        "linux-i686")
            GCC=1
            LINUX=1
            EXTRA_FLAGS="-m32"
            # TOOLCHAIN_PREFIX="i686-linux-gnu"
            # TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            ;;
        "native")
            target=$(uname -s)
            check_target
            if [ "${target}" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
                MACOS_UNIVERSAL=1
            fi
            ;;
        default|*)
            echo "Invalid target '${target}', possible values are:"
            echo "\tmacos"
            echo "\tmacos-old"
            echo "\tmacos-universal"
            echo "\twasm"
            echo "\twin32"
            echo "\twin64"
            echo "\tnative"
            if [ -z "${SOURCING_FILES}" ]; then
                exit 2
            else
                INVALID_TARGET=1
            fi
            ;;
    esac
}

check_target
