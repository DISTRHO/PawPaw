#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

./bootstrap-common.sh "${target}"
./bootstrap-plugins.sh "${target}"
./bootstrap-qt.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# file/magic (posix only)

# if [ "${WIN32}" -eq 0 ]; then
#     download file "${FILE_VERSION}" "ftp://ftp.astron.com/pub/file"
#     build_autoconf file "${FILE_VERSION}"
# fi

# ---------------------------------------------------------------------------------------------------------------------
