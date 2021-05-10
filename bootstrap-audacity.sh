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
# ./bootstrap-plugins.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# wxwidgets

# wxwidgets_args+=" -DwxWidgets_USE_REL_AND_DBG=no"
# wxwidgets_args+=" -Daudacity_use_pch=no"

# override PawPaw default
wxwidgets_args="-DBUILD_SHARED_LIBS=ON"

# win32
wxwidgets_args+=" -DwxUSE_ACCESSIBILITY=YES"
wxwidgets_args+=" -DwxBUILD_PRECOMP=YES"

wxwidgets_args+=" -DwxBUILD_CXX_STANDARD=14"
wxwidgets_args+=" -DwxUSE_EXPAT=builtin"
wxwidgets_args+=" -DwxUSE_LIBJPEG=builtin"
wxwidgets_args+=" -DwxUSE_LIBPNG=builtin"
wxwidgets_args+=" -DwxUSE_LIBTIFF=builtin"
wxwidgets_args+=" -DwxUSE_REGEX=builtin"
wxwidgets_args+=" -DwxUSE_ZLIB=builtin"
# wxwidgets_args+=" -D"

# custom wxwidgets flags
# wxwidgets_args+=" -DwxBUILD_MONOLITHIC=ON"
# wxwidgets_args+=" -DwxBUILD_PRECOMP=OFF"
# wxwidgets_args+=" -DwxBUILD_OPTIMISE=ON"
wxwidgets_args+=" -DwxBUILD_SHARED=ON"
# win32 only
wxwidgets_args+=" -DwxUSE_WINSOCK2=yes"

# set(wxSOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
# set(wxBINARY_DIR ${CMAKE_BINARY_DIR})
# set(wxOUTPUT_DIR ${wxBINARY_DIR}/lib)
# set(wxVERSION 3.1.3)
# set(wxCOPYRIGHT "1992-2019 wxWidgets")

win32_target=_WIN32_WINNT_WIN7
export EXTRA_CXXFLAGS="-DWINVER=${win32_target} -D_WIN32_WINNT=${win32_target} -D_WIN32_IE=${win32_target}"

download wxWidgets "audacity-fixes-3.1.3" "https://github.com/audacity/wxWidgets.git" "" "git"
build_cmake wxWidgets "audacity-fixes-3.1.3" "${wxwidgets_args}"

# ---------------------------------------------------------------------------------------------------------------------
