#!/bin/bash

CLANG=0
GCC=0

CROSS_COMPILING=0
INVALID_TARGET=0

LINUX=0
MACOS=0
MACOS_10_15=0
MACOS_UNIVERSAL=0
WASM=0
WIN32=0
WIN64=0

unset EXE_WRAPPER
unset TOOLCHAIN_PREFIX
unset TOOLCHAIN_PREFIX_

function check_target() {
    case "${target}" in
        "Darwin")
            CLANG=1
            MACOS=1
            if [ "$(uname -m)" = "arm64" ]; then
                MACOS_UNIVERSAL=1
            fi
            ;;
        "macos"|"macos-intel")
            CLANG=1
            MACOS=1
            if [ "$(uname -m)" = "arm64" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "macos-10.15")
            CLANG=1
            MACOS=1
            MACOS_10_15=1
            if [ "$(uname -m)" = "arm64" ]; then
                CROSS_COMPILING=1
            fi
            ;;
        "macos-universal")
            CLANG=1
            MACOS=1
            MACOS_UNIVERSAL=1
            ;;
        "macos-universal-10.15")
            CLANG=1
            MACOS=1
            MACOS_10_15=1
            MACOS_UNIVERSAL=1
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
                CMAKE_SYSTEM_PROCESSOR="i686"
                PAWPAW_SKIP_LTO=1
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
                CMAKE_SYSTEM_PROCESSOR="x86_64"
                PAWPAW_SKIP_LTO=1
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
                CMAKE_SYSTEM_PROCESSOR="aarch64"
                export EXE_WRAPPER="qemu-aarch64-static"
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
                CMAKE_SYSTEM_PROCESSOR="armv7"
                export EXE_WRAPPER="qemu-arm-static"
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
                CMAKE_SYSTEM_PROCESSOR="i386"
                export EXE_WRAPPER="qemu-i386-static"
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
                CMAKE_SYSTEM_PROCESSOR="riscv64"
                export EXE_WRAPPER="qemu-riscv64-static"
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
                CMAKE_SYSTEM_PROCESSOR="x86_64"
                export EXE_WRAPPER="qemu-x86_64-static"
            fi
            ;;
        "native")
            target=$(uname -s)
            check_target
            ;;
        default|*)
            echo "Invalid target '${target}', possible values are:"
            echo "\tlinux"
            echo "\tlinux-aarch64|linux-arm64"
            echo "\tlinux-armhf"
            echo "\tlinux-i686|linux-i386"
            echo "\tlinux-riscv64"
            echo "\tlinux-x86_64"
            echo "\tmacos|macos-intel"
            echo "\tmacos-10.15"
            echo "\tmacos-universal"
            echo "\tmacos-universal-10.15"
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

# always skip tests when cross-compiling
if [ "${CROSS_COMPILING}" -eq 1 ]; then
    PAWPAW_SKIP_TESTS=${PAWPAW_SKIP_TESTS:=1}
fi

# always skip lto and stripping if building in debug mode
if [ -n "${PAWPAW_DEBUG}" ] && [ "${PAWPAW_DEBUG}" -eq 1 ]; then
    PAWPAW_SKIP_LTO=1
    PAWPAW_SKIP_STRIPPING=1
fi
