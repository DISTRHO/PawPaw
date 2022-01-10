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

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------

# TODO check for depedencies:
# - autopoint

# ---------------------------------------------------------------------------------------------------------------------
# aften (macos only)

if [ "${MACOS}" -eq 1 ]; then
    download aften "${AFTEN_VERSION}" "${AFTEN_URL}" "tar.bz2"
    if [ ! -f "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/.stamp_installed" ]; then
        rm -f "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/.stamp_installed_libs"
    fi
    build_cmake aften "${AFTEN_VERSION}" "-DHAVE_MMX=ON -DHAVE_SSE=ON -DHAVE_SSE2=ON"
    if [ ! -f "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/.stamp_installed_libs" ]; then
        cp -v "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/build/libaften_pcm.a" "${PAWPAW_PREFIX}/lib/libaften_pcm.a"
        cp -v "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/build/libaften_static.a" "${PAWPAW_PREFIX}/lib/libaften.a"
        touch "${PAWPAW_BUILDDIR}/aften-${AFTEN_VERSION}/.stamp_installed_libs"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# db

download db "${DB_VERSION}" "${DB_URL}"

# based on build_autoconf
function build_custom_db() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules+=" --host=${TOOLCHAIN_PREFIX}"
    fi
    if [ "${MACOS}" -eq 1 ]; then
        extraconfrules+=" --with-mutex=x86_64/gcc-assembly db_cv_atomic=x86/gcc-assembly"
    fi
    if [ "${WIN32}" -eq 1 ]; then
        extraconfrules+=" --enable-mingw"
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

build_custom_db db "${DB_VERSION}" "--disable-java --disable-replication --disable-sql --disable-tcl"

# ---------------------------------------------------------------------------------------------------------------------
# rtaudio (download, win32 only)

if [ "${WIN32}" -eq 1 ]; then
    git_clone rtaudio "${RTAUDIO_VERSION}" "${RTAUDIO_URL}"
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
    download portaudio19 "${PORTAUDIO_VERSION}" "${PORTAUDIO_URL}" "orig.tar.gz"
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
    build_autoconf portaudio19 "${PORTAUDIO_VERSION}" "--enable-cxx --with-asiodir=${ASIO_DIR} --with-winapi=asio,directx,wasapi,wdmks,wmme"
    install_file portaudio19 "${PORTAUDIO_VERSION}" "include/pa_asio.h" "include"
fi

# ---------------------------------------------------------------------------------------------------------------------
# tre (win32 only)

if [ "${WIN32}" -eq 1 ]; then
    git_clone tre "${TRE_VERSION}" "${TRE_URL}"
    build_autoconfgen tre "${TRE_VERSION}" "--disable-nls"
fi

# ---------------------------------------------------------------------------------------------------------------------
# tre (win64 32bit build)
# NOTE: this must be the last item to build

if [ "${WIN64}" -eq 1 ]; then
    target="win32"
    source setup/check_target.sh
    source setup/env.sh
    PAWPAW_BUILDDIR="${PAWPAW_DIR}/builds/win64"
    PAWPAW_PREFIX="${PAWPAW_DIR}/targets/win64"
    source setup/functions.sh

    copy_download tre tre-x32 "${TRE_VERSION}"
    build_autoconfgen tre-x32 "${TRE_VERSION}" "--disable-nls --libdir=${PAWPAW_PREFIX}/lib32"

    if [ ! -e "${PAWPAW_PREFIX}/lib/libtre32.a" ]; then
        ln -s "${PAWPAW_PREFIX}/lib32/libtre.a" "${PAWPAW_PREFIX}/lib/libtre32.a"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
