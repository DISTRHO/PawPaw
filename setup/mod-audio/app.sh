#!/bin/bash

set -e

cd $(dirname ${0})/../..
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------
# check target

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------

export PAWPAW_SKIP_LTO=1
source local.env win64

# export PYTHONPATH="$(pwd);${PAWPAW_PREFIX}/lib/python3.8/site-packages"
export PYTHONPATH="Z:\\home\\falktx\\PawPawBuilds\\targets\\win64\\lib\\python3.8\\site-packages"

cd ../../MOD/mod-ui
# rm -rf build
${EXE_WRAPPER} "${PAWPAW_PREFIX}/bin/python3${APP_EXT}" "${PAWPAW_ROOT}/setup/mod-audio/app.py" build_exe

# ---------------------------------------------------------------------------------------------------------------------
