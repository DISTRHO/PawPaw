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

export PAWPAW_SKIP_GLIB=1
export PAWPAW_SKIP_LV2=1
export PAWPAW_SKIP_SAMPLERATE=1

./bootstrap-common.sh "${target}"
./bootstrap-plugins.sh "${target}"

# nothing to do on wasm
if [ "${target}" = "wasm" ]; then
    exit 0
fi

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
