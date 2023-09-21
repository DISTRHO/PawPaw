#!/bin/bash

# set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"
plugin="${2}"

if [ -z "${target}" ] || [ -z "${plugin}" ]; then
    echo "usage: ${0} <target> <plugin>"
    exit 1
fi

# TODO check that bootstrap.sh has been run

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

PAWPAW_QUIET=1
source local.env "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# merged usr mode

mkdir -p "${PAWPAW_PREFIX}/usr"

if [ ! -e "${PAWPAW_PREFIX}/usr/bin" ]; then
    ln -s ../bin "${PAWPAW_PREFIX}/usr/bin"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/docs" ]; then
    ln -s ../docs "${PAWPAW_PREFIX}/usr/docs"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/etc" ]; then
    ln -s ../etc "${PAWPAW_PREFIX}/usr/etc"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/include" ]; then
    ln -s ../include "${PAWPAW_PREFIX}/usr/include"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/lib" ]; then
    ln -s ../lib "${PAWPAW_PREFIX}/usr/lib"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/share" ]; then
    ln -s ../share "${PAWPAW_PREFIX}/usr/share"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/var" ]; then
    ln -s ../var "${PAWPAW_PREFIX}/usr/var"
fi

# ---------------------------------------------------------------------------------------------------------------------

export CMAKE
export PAWPAW_BUILDDIR
export PAWPAW_DOWNLOADDIR
export PAWPAW_PREFIX
export TOOLCHAIN_PREFIX

if [ ! -e mod-plugin-builder ]; then
    echo "missing mod-plugin-builder"
    exit 1
fi

make -f setup/mod-audio/builder.mk pkgname="${plugin}" ${MAKE_ARGS} WITH_LTO=false VERBOSE=1

# ---------------------------------------------------------------------------------------------------------------------
