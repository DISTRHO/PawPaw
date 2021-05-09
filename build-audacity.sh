#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

JACK2_VERSION=${JACK2_VERSION:=git}
JACK_ROUTER_VERSION=${JACK_ROUTER_VERSION:=6c2e532bb05d2ba59ef210bef2fe270d588c2fdf}
QJACKCTL_VERSION=${QJACKCTL_VERSION:=0.9.2}

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependency

# ./bootstrap-audacity.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------

audacity_repo="https://github.com/jackaudio/jack2.git"
# audacity_prefix="${PAWPAW_PREFIX}-audacity"

audacity_args="-DCMAKE_BUILD_TYPE=Release -DwxWidgets_USE_REL_AND_DBG=no -Daudacity_use_pch=no"

audacity_args+=" -Daudacity_use_wxwidgets=local"

# audacity_args+=" -DwxWidgets_ROOT_DIR=${PAWPAW_PREFIX}"
# audacity_args+=" -DwxWidgets_LIB_DIR=${PAWPAW_PREFIX}/lib/mswu"
# audacity_args+=" -DwxWidgets_CONFIGURATION=mswu"

# audacity_args+=" -DwxWidgets_FOUND=BOOL:TRUE"
# audacity_args+=" -DwxWidgets_INCLUDE_DIRS=${PAWPAW_PREFIX}/include"
# audacity_args+=" -DwxWidgets_LIBRARIES=${PAWPAW_PREFIX}/lib/mswu"

download audacity "e93fdd16c50d9d4630bc64595990e2ee0f96bc17" "https://github.com/KXStudio/audacity.git" "" "git"
build_cmake audacity "e93fdd16c50d9d4630bc64595990e2ee0f96bc17" "${audacity_args}"

# ---------------------------------------------------------------------------------------------------------------------
