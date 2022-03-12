#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------
# check target

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependencies

export PAWPAW_SKIP_SAMPLERATE=1

./bootstrap-common.sh "${target}"

# on Windows, we just build the whole thing
if [ "${target}" = "win32" ] || [ "${target}" = "win64" ]; then
    ./bootstrap-carla.sh "${target}"
    exit 0
fi

# otherwise we build a very tiny set of dependencies

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# file/magic (posix only)

if [ "${WIN32}" -eq 0 ]; then
    download file "${FILE_VERSION}" "${FILE_URL}"
    build_autoconf file "${FILE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# liblo

LIBLO_EXTRAFLAGS="--enable-threads --disable-examples --disable-tools"

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    LIBLO_EXTRAFLAGS+=" --disable-tests"
fi

# auto-detection fails
if [ "${MACOS}" -eq 1 ]; then
    LIBLO_EXTRAFLAGS+=" ac_cv_func_select=yes ac_cv_func_poll=yes ac_cv_func_setvbuf=yes"
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        LIBLO_EXTRAFLAGS+=" ac_cv_c_bigendian=universal"
    fi
fi

download liblo "${LIBLO_VERSION}" "${LIBLO_URL}"
build_autoconf liblo "${LIBLO_VERSION}" "${LIBLO_EXTRAFLAGS}"

# FIXME tests fail on macOS
if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${MACOS}" -eq 0 ]; then
    run_make liblo "${LIBLO_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# wine bootstrap for python (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
