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
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependencies

./bootstrap-common.sh "${target}"
./bootstrap-jack2.sh "${target}"
./bootstrap-plugins.sh "${target}"
./bootstrap-python.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# jack2

JACK2_EXTRAFLAGS=""

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${LINUX}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=linux"
    elif [ "${MACOS}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=darwin"
    elif [ "${WIN32}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=win32"
    fi
fi

if [ "${WIN32}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --static"
fi

JACK2_VERSION="250420381b1a6974798939ad7104ab1a4b9a9994"
JACK2_URL="https://github.com/jackaudio/jack2.git"

download jack2 "${JACK2_VERSION}" "${JACK2_URL}" "" "git"
build_waf jack2 "${JACK2_VERSION}" "${JACK2_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# aggdraw

AGGDRAW_VERSION="1.3.11"

if [ "${WIN32}" -eq 1 ]; then
    export AGGDRAW_FREETYPE_ROOT="${PAWPAW_PREFIX}"
    export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 freetype2 libpng)"
    export EXTRA_LDFLAGS="-shared $(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 freetype2 libpng) -lgdi32 -lkernel32 -luser32"
fi

download aggdraw "${AGGDRAW_VERSION}" "https://files.pythonhosted.org/packages/ef/29/fddf555c68920bb0aff977425af786226db2a78379e706951ff32b4492ef"
build_python aggdraw "${AGGDRAW_VERSION}"

unset AGGDRAW_FREETYPE_ROOT

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/aggdraw.pyd" ]; then
        ln -sv "${PYTHONPATH}"/aggdraw-*.egg/*.so "${PYTHONPATH}/aggdraw.pyd"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
# tornado

TORNADO_VERSION="4.3"

download tornado "${TORNADO_VERSION}" "https://files.pythonhosted.org/packages/21/29/e64c97013e97d42d93b3d5997234a6f17455f3744847a7c16289289f8fa6"
build_python tornado "${TORNADO_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
