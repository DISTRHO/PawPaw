#!/bin/bash

CLANG=0
GCC=0

CROSS_COMPILING=0
INVALID_TARGET=0

LINUX=0
MACOS=0
MACOS_UNIVERSAL=0
MACOS_UNIVERSAL_10_15=0
WASM=0
WIN32=0
WIN64=0

unset EXE_WRAPPER
unset TOOLCHAIN_PREFIX
unset TOOLCHAIN_PREFIX_

function check_target() {
    case "${target}" in
        "macos"|"Darwin")
            CLANG=1
            MACOS=1
            ;;
        "macos-universal")
            CLANG=1
            MACOS=1
            MACOS_UNIVERSAL=1
            ;;
        "macos-10.15"|"macos-universal-10.15")
            CLANG=1
            MACOS=1
            MACOS_UNIVERSAL=1
            MACOS_UNIVERSAL_10_15=1
            ;;
        "wasm")
            CLANG=1
            CROSS_COMPILING=1
            WASM=1
            PAWPAW_SKIP_LTO=1
            export EXE_WRAPPER="emrun --no_server"
            ;;
        "win32"|"MINGW32"*)
            GCC=1
            WIN32=1
            if [ "$(uname -o)" != "Msys" ] && [ "$(uname -o)" != "Cygwin" ]; then
                CROSS_COMPILING=1
                TOOLCHAIN_PREFIX="i686-w64-mingw32"
                TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
                export EXE_WRAPPER="wine"
            fi
            ;;
        "win64"|"MINGW64"*)
            GCC=1
            WIN32=1
            WIN64=1
            if [ "$(uname -o)" != "Msys" ] && [ "$(uname -o)" != "Cygwin" ]; then
                CROSS_COMPILING=1
                TOOLCHAIN_PREFIX="x86_64-w64-mingw32"
                TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
                export EXE_WRAPPER="wine"
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
            if [ "$(uname -m)" = "aarch64" ]; then
                LINUX_TARGET="linux-aarch64"
            elif [ "$(uname -m)" = "arm" ]; then
                LINUX_TARGET="linux-armhf"
            elif [ "$(uname -m)" = "i386" ] || [ "$(uname -m)" = "i686" ]; then
                LINUX_TARGET="linux-i686"
            elif [ "$(uname -m)" = "riscv64" ]; then
                LINUX_TARGET="linux-riscv64"
            elif [ "$(uname -m)" = "x86_64" ]; then
                LINUX_TARGET="linux-x86_64"
            fi
            ;;
        "linux-aarch64"|"linux-arm64")
            GCC=1
            LINUX=1
            LINUX_TARGET="linux-aarch64"
            TOOLCHAIN_PREFIX="aarch64-linux-gnu"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            if [ "$(uname -m)" != "aarch64" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "linux-armhf")
            GCC=1
            LINUX=1
            LINUX_TARGET="linux-armhf"
            TOOLCHAIN_PREFIX="arm-linux-gnueabihf"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            if [ "$(uname -m)" != "arm" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "linux-i686"|"linux-i386")
            GCC=1
            LINUX=1
            LINUX_TARGET="linux-i686"
            EXTRA_FLAGS="-m32"
            TOOLCHAIN_PREFIX="i686-linux-gnu"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            if [ "$(uname -m)" != "i386" ] && [ "$(uname -m)" != "i686" ] && [ "$(uname -m)" != "x86_64" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "linux-riscv64")
            GCC=1
            LINUX=1
            LINUX_TARGET="linux-riscv64"
            TOOLCHAIN_PREFIX="riscv64-linux-gnu"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            if [ "$(uname -m)" != "riscv64" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "linux-x86_64")
            GCC=1
            LINUX=1
            LINUX_TARGET="linux-x86_64"
            EXTRA_FLAGS="-m64"
            TOOLCHAIN_PREFIX="x86_64-linux-gnu"
            TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
            if [ "$(uname -m)" != "x86_64" ]; then
                CROSS_COMPILING=1
            fi
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
