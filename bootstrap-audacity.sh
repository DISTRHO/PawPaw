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

using_qt=0

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependencies

./bootstrap-common.sh "${target}"
# ./bootstrap-plugins.sh "${target}"

if [ ${using_qt} -eq 1 ]; then
    ./bootstrap-qt.sh "${target}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# wxwidgets

# override PawPaw default
wxwidgets_args="-DBUILD_SHARED_LIBS=ON"

# common flags
wxwidgets_args+=" -DwxBUILD_CXX_STANDARD=14"
wxwidgets_args+=" -DwxBUILD_MONOLITHIC=ON"
wxwidgets_args+=" -DwxBUILD_OPTIMISE=ON"
wxwidgets_args+=" -DwxBUILD_SHARED=ON"
wxwidgets_args+=" -DwxUSE_EXPAT=builtin"
wxwidgets_args+=" -DwxUSE_LIBJPEG=builtin"
wxwidgets_args+=" -DwxUSE_LIBPNG=builtin"
wxwidgets_args+=" -DwxUSE_LIBTIFF=builtin"
wxwidgets_args+=" -DwxUSE_REGEX=builtin"
wxwidgets_args+=" -DwxUSE_ZLIB=builtin"

if [ ${using_qt} -eq 1 ]; then
    wxwidgets_args+=" -DwxBUILD_TOOLKIT=qt"
fi

# these match upstream cmake setup
if [ "${MACOS}" -eq 1 ]; then
    wxwidgets_args+=" -DwxUSE_ACCESSIBILITY=YES"
    wxwidgets_args+=" -DwxBUILD_PRECOMP=NO"
elif [ "${WIN32}" -eq 1 ]; then
    wxwidgets_args+=" -DwxUSE_ACCESSIBILITY=YES"
    wxwidgets_args+=" -DwxBUILD_PRECOMP=YES"
else
    wxwidgets_args+=" -DwxUSE_ACCESSIBILITY=NO"
    wxwidgets_args+=" -DwxBUILD_PRECOMP=YES"
fi

# needed for mingw
if [ "${WIN32}" -eq 1 ]; then
    wxwidgets_args+=" -DwxUSE_WINSOCK2=yes"
    win32_target=_WIN32_WINNT_WIN7
    export EXTRA_CXXFLAGS="-DWINVER=${win32_target} -D_WIN32_WINNT=${win32_target} -D_WIN32_IE=${win32_target}"
fi

# needed?
# set(wxVERSION 3.1.3)
# set(wxCOPYRIGHT "1992-2019 wxWidgets")

download wxWidgets "audacity-fixes-3.1.3" "https://github.com/audacity/wxWidgets.git" "" "git"
build_cmake wxWidgets "audacity-fixes-3.1.3" "${wxwidgets_args}"

# ---------------------------------------------------------------------------------------------------------------------
