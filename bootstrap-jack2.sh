#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

JACK2_VERSION=${JACK2_VERSION:=git}
QJACKCTL_VERSION=${QJACKCTL_VERSION:=0.6.2}

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target> [package-build?]"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------

./bootstrap-common.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------

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
    if [ "${WIN32}" -eq 1 ]; then
        extraconfrules="--enable-mingw ${extraconfrules}"
    fi

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}/build_unix"
        ../dist/configure --enable-static --disable-shared --disable-debug --disable-doc --disable-maintainer-mode --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
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
build_custom_db db "${DB_VERSION}" "--disable-java --disable-replication --disable-sql --disable-tcl"
# --enable-posixmutexes --enable-compat185 --enable-cxx --enable-dbm --enable-stl

# ---------------------------------------------------------------------------------------------------------------------
# opus

download opus "${OPUS_VERSION}" "https://archive.mozilla.org/pub/opus"
build_autoconf opus "${OPUS_VERSION}" "--disable-extra-programs --enable-custom-modes --enable-float-approx"

# ---------------------------------------------------------------------------------------------------------------------
# rtaudio (download, win32 only)

if [ "${WIN32}" -eq 1 ]; then
    download rtaudio "${RTAUDIO_VERSION}" "https://github.com/falkTX/rtaudio.git" "" "git"
    # fixes for portaudio
    ASIO_DIR="${PAWPAW_BUILDDIR}/rtaudio-${RTAUDIO_VERSION}/include"
    if [ -d "${ASIO_DIR}" ]; then
        link_file rtaudio "${RTAUDIO_VERSION}" "." "include/common"
        link_file rtaudio "${RTAUDIO_VERSION}" "." "include/host"
        link_file rtaudio "${RTAUDIO_VERSION}" "." "include/pc"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# portaudio (win32 only)

if [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS="-I${ASIO_DIR}"
    export EXTRA_CXXFLAGS="-I${ASIO_DIR}"
    export EXTRA_MAKE_ARGS="-j 1"
    download portaudio19 "${PORTAUDIO_VERSION}" "http://deb.debian.org/debian/pool/main/p/portaudio19" "orig.tar.gz"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/audioclient.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/devicetopology.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/endpointvolume.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/functiondiscoverykeys.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/ksguid.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/ksproxy.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/ksuuids.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/mmdeviceapi.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/propkeydef.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/propsys.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/rpcsal.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/sal.h"
    remove_file portaudio19 "${PORTAUDIO_VERSION}" "src/hostapi/wasapi/mingw-include/structuredquery.h"
    build_autoconf portaudio19 "${PORTAUDIO_VERSION}" "--enable-cxx --with-asiodir="${ASIO_DIR}" --with-winapi=asio,directx,wasapi,wdmks,wmme"
    install_file portaudio19 "${PORTAUDIO_VERSION}" "include/pa_asio.h" "include"
fi

# ---------------------------------------------------------------------------------------------------------------------
# tre (win32 only)

if [ "${WIN32}" -eq 1 ]; then
    download tre "${TRE_VERSION}" "https://laurikari.net/tre"
    build_autoconf tre "${TRE_VERSION}" "--disable-nls"
fi

# ---------------------------------------------------------------------------------------------------------------------
