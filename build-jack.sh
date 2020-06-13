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

# TODO check that bootstrap.sh has been run

# TODO add these libraries
# - opus (custom)

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# aften (macos only)

if [ "${MACOS}" -eq 1 ]; then
    download aften "${AFTEN_VERSION}" "http://downloads.sourceforge.net/aften" "tar.bz2"
    build_cmake aften "${AFTEN_VERSION}"
    if [ ! -f "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/.stamp_installed_libs" ]; then
    	cp -v "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/build/libaften_pcm.a" "${PAWPAW_PREFIX}/lib/libaften_pcm.a"
    	cp -v "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/build/libaften_static.a" "${PAWPAW_PREFIX}/lib/libaften.a"
    	touch "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/.stamp_installed_libs"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# db

download db "${DB_VERSION}" "https://download.oracle.com/berkeley-db"

# based on build_autoconf
function build_custom_db() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules="--host=${TOOLCHAIN_PREFIX} ${extraconfrules}"
    fi

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}/build_unix"
        ../dist/configure --enable-static --disable-shared --disable-maintainer-mode --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
        touch ../.stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}/build_unix"
        make ${MAKE_ARGS}
        touch ../.stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}/build_unix"
        make ${MAKE_ARGS} install
        touch ../.stamp_installed
        popd
    fi

    _postbuild
}

patch_file db "${DB_VERSION}" "src/dbinc/atomic.h" 's/__atomic_compare_exchange/__db_atomic_compare_exchange/'
build_custom_db db "${DB_VERSION}" --disable-java --disable-sql --disable-tcl

# --enable-posixmutexes --enable-compat185 --enable-cxx --enable-dbm --enable-stl
# make LIBSO_LIBS=-lpthread

# ---------------------------------------------------------------------------------------------------------------------

if [ ! -d jack2 ]; then
	git clone --recursive git@github.com:jackaudio/jack2.git
fi

ln -sf "$(pwd)/jack2" "${PAWPAW_BUILDDIR}/jack2-git"
rm -f "${PAWPAW_BUILDDIR}/jack2-git/.stamp_built"
build_waf jack2 "git"
# "--lv2dir=${PAWPAW_PREFIX}/lib/lv2"

# ---------------------------------------------------------------------------------------------------------------------
