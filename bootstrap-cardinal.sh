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
# wine bootstrap for python (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
