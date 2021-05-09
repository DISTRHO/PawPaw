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

./bootstrap-common.sh "${target}"
./bootstrap-plugins.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# wxwidgets

download wxWidgets "audacity-fixes-3.1.3" "https://github.com/audacity/wxWidgets.git" "" "git"
build_cmake wxWidgets "audacity-fixes-3.1.3"

# ---------------------------------------------------------------------------------------------------------------------
