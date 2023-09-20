#!/bin/bash

set -e

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

export CMAKE
export PAWPAW_BUILDDIR
export PAWPAW_DOWNLOADDIR
export PAWPAW_PREFIX

make -f setup/mod-audio/builder.mk pkgname="${plugin}"

# ---------------------------------------------------------------------------------------------------------------------
