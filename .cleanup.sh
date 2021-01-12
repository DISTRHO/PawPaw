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

source setup/check_target.sh
source setup/env.sh

# ---------------------------------------------------------------------------------------------------------------------

set -u

echo "Cleaning up build dir..."
rm -rf ${PAWPAW_BUILDDIR}/*/*
rm -rf ${PAWPAW_BUILDDIR}/*/._*
rm -rf ${PAWPAW_BUILDDIR}/*/.hg*
rm -rf ${PAWPAW_BUILDDIR}/*/.git*
rm -rf ${PAWPAW_BUILDDIR}/*/.waf-*
rm -rf ${PAWPAW_BUILDDIR}/*/.deps
rm -rf ${PAWPAW_BUILDDIR}/*/.libs
rm -rf ${PAWPAW_BUILDDIR}/*/.lock-waf_linux_build

for dir in $(find "${PAWPAW_BUILDDIR}" -maxdepth 1 -type d); do
    echo "Directory '${dir}' is now clean"
    touch ${dir}/.stamp_cleanup
done

# ---------------------------------------------------------------------------------------------------------------------
