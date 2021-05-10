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

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependency

./bootstrap-audacity.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------

# audacity_repo="https://github.com/jackaudio/jack2.git"
# audacity_prefix="${PAWPAW_PREFIX}-audacity"

audacity_args=""
audacity_args+=" -DwxWidgets_USE_REL_AND_DBG=no"
audacity_args+=" -Daudacity_use_pch=no"

audacity_args+=" -Daudacity_use_libflac=system"
audacity_args+=" -Daudacity_use_libogg=system"
audacity_args+=" -Daudacity_use_libsndfile=system"
audacity_args+=" -Daudacity_use_libvorbis=system"
audacity_args+=" -Daudacity_use_wxwidgets=system"

# TODO
audacity_args+=" -Daudacity_use_expat=local"
audacity_args+=" -Daudacity_use_lame=local"
audacity_args+=" -Daudacity_use_libsoxr=local"
audacity_args+=" -Daudacity_use_portaudio-v19=local"
audacity_args+=" -Daudacity_use_sqlite=local"
audacity_args+=" -Daudacity_use_libid3tag=local"
audacity_args+=" -Daudacity_use_libmad=local"
audacity_args+=" -Daudacity_use_libnyquist=local"
audacity_args+=" -Daudacity_use_libvamp=local"
audacity_args+=" -Daudacity_use_lv2=local"
audacity_args+=" -Daudacity_use_portmidi=local"
audacity_args+=" -Daudacity_use_portmixer=local"
audacity_args+=" -Daudacity_use_portsmf=local"
audacity_args+=" -Daudacity_use_libsbsms=local"
audacity_args+=" -Daudacity_use_soundtouch=local"
audacity_args+=" -Daudacity_use_twolame=local"

# optional
# audacity_args+=" -Daudacity_use_ffmpeg=local"

# FIXME
audacity_args+=" -Daudacity_use_pa_jack=off"

# audacity_args+=" -DwxWidgets_ROOT_DIR=${PAWPAW_PREFIX}"

# audacity_args+=" -DwxWidgets_FOUND=BOOL:TRUE"
# audacity_args+=" -DwxWidgets_INCLUDE_DIRS_NO_SYSTEM"

# audacity_args+=" -DwxWidgets_INCLUDE_DIRS=${PAWPAW_PREFIX}/include;${PAWPAW_PREFIX}/lib/gcc_x64_dll/mswu"
# audacity_args+=" -DwxWidgets_LIBRARIES='winmm comctl32 uuid oleacc uxtheme rpcrt4 shlwapi version wsock32'"
# audacity_args+=" -DwxWidgets_LIBRARY_DIRS=${PAWPAW_PREFIX}/lib/gcc_x64_dll"
# audacity_args+=" -Dtoolkit=mswu"
# audacity_args+=" -D"
# audacity_args+=" -D"

audacity_args+=" -DwxWidgets_FIND_STYLE=win32" # must be forced in the cmake file
audacity_args+=" -DwxWidgets_ROOT_DIR=${PAWPAW_PREFIX}"
audacity_args+=" -DwxWidgets_LIB_DIR=${PAWPAW_PREFIX}/lib/gcc_x64_dll"
audacity_args+=" -DwxWidgets_CONFIGURATION=mswu"
audacity_args+=" -DWX_ROOT_DIR=${PAWPAW_PREFIX}"

win32_target=_WIN32_WINNT_WIN7
export EXTRA_CXXFLAGS="-DWINVER=${win32_target} -D_WIN32_WINNT=${win32_target} -D_WIN32_IE=${win32_target} -std=gnu++14"
# -DwxUSE_UNICODE_WINDOWS_H=1"

download audacity "e93fdd16c50d9d4630bc64595990e2ee0f96bc17" "https://github.com/KXStudio/audacity.git" "" "git"
build_cmake audacity "e93fdd16c50d9d4630bc64595990e2ee0f96bc17" "${audacity_args}"

# ---------------------------------------------------------------------------------------------------------------------
