#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

JACK2_VERSION=git
QJACKCTL_VERSION=0.6.2

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------

# TODO check that bootstrap.sh has been run

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
    link_file rtaudio "${RTAUDIO_VERSION}" "." "include/common"
    link_file rtaudio "${RTAUDIO_VERSION}" "." "include/host"
    link_file rtaudio "${RTAUDIO_VERSION}" "." "include/pc"
fi

# ---------------------------------------------------------------------------------------------------------------------
# portaudio (win32 only)

if [ "${WIN32}" -eq 1 ]; then
    ASIO_DIR="${PAWPAW_BUILDDIR}/rtaudio-${RTAUDIO_VERSION}/include"
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
fi

# ---------------------------------------------------------------------------------------------------------------------
# tre (win32 only)

if [ "${WIN32}" -eq 1 ]; then
    download tre "${TRE_VERSION}" "https://laurikari.net/tre"
    build_autoconf tre "${TRE_VERSION}" "--disable-nls"
fi

# ---------------------------------------------------------------------------------------------------------------------
# stop here if CI test build

if [ -n "${TRAVIS_BUILD_DIR}" ]; then
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------------------
# and finally jack2

jack2_repo="git@github.com:jackaudio/jack2.git"
jack2_prefix="${PAWPAW_PREFIX}/jack2"

jack2_args="--prefix=${jack2_prefix}"
# if [ "${MACOS_OLD}" -eq 1 ] || [ "${WIN64}" -eq 1 ]; then
#     jack2_args="${jack2_args} --mixed"
# fi
if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${LINUX}" -eq 1 ]; then
        jack2_args="${jack2_args} --platform=linux"
    elif [ "${MACOS}" -eq 1 ]; then
        jack2_args="${jack2_args} --platform=darwin"
    elif [ "${WIN32}" -eq 1 ]; then
        jack2_args="${jack2_args} --platform=win32"
    fi
fi

if [ "${MACOS_OLD}" -eq 1 ]; then
    patch_file jack2 "git" "wscript" '/-std=gnu++11/d'
    patch_file jack2 "git" "wscript" '/-Wno-deprecated-register/d'
fi

if [ "${JACK2_VERSION}" = "git" ]; then
    if [ ! -d jack2 ]; then
        git clone --recursive "${jack2_repo}"
    fi
    if [ ! -e "${PAWPAW_BUILDDIR}/jack2-git" ]; then
        ln -sf "$(pwd)/jack2" "${PAWPAW_BUILDDIR}/jack2-git"
    fi
    rm -f "${PAWPAW_BUILDDIR}/jack2-git/.stamp_built"
else
    download jack2 "${JACK2_VERSION}" "${jack2_repo}" "" "git"
fi

build_waf jack2 "${JACK2_VERSION}" "${jack2_args}"

# remove useless dbus-specific file
rm "${PAWPAW_PREFIX}/jack2/bin/jack_control"

# copy jack pkg-config file to main system, so qjackctl can find it
if [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc" ]; then
    cp -v "${PAWPAW_PREFIX}/jack2/lib/pkgconfig/jack.pc" "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc"

    # patch pkg-config file for static win32 builds in regular prefix
    if [ "${WIN32}" -eq 1 ]; then
        if [ "${WIN64}" -eq 1 ]; then
            s="64"
        else
            s=""
        fi
        # FIXME rule that works for server lib too, maybe ignoring suffix even
        sed -i -e "s/lib -ljack${s}/lib -Wl,-Bdynamic -ljack${s} -Wl,-Bstatic/" "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc"
    fi
fi

if [ "${MACOS}" -eq 1 ]; then
    for f in $(ls "${PAWPAW_PREFIX}/jack2/bin/"); do
        patch_osx_binary_libs "${PAWPAW_PREFIX}/jack2/bin/${f}"
    done
fi

# ---------------------------------------------------------------------------------------------------------------------
# if qt is available, build qjackctl

if [ -f "${PAWPAW_PREFIX}/bin/moc" ]; then
    download qjackctl "${QJACKCTL_VERSION}" https://download.sourceforge.net/qjackctl

    if [ "${WIN64}" -eq 1 ]; then
        patch_file qjackctl "${QJACKCTL_VERSION}" "configure" 's/-ljack /-Wl,-Bdynamic -ljack64 -Wl,-Bstatic /'
    elif [ "${WIN32}" -eq 1 ]; then
        patch_file qjackctl "${QJACKCTL_VERSION}" "configure" 's/-ljack /-Wl,-Bdynamic -ljack -Wl,-Bstatic /'
    fi

    build_autoconf qjackctl "${QJACKCTL_VERSION}" "--enable-jack-version"

    if [ "${MACOS}" -eq 1 ]; then
        qjackctl_dir="${PAWPAW_PREFIX}/bin/qjackctl.app/Contents/MacOS"
        patch_osx_binary_libs "${qjackctl_dir}/qjackctl"
        if [ ! -e "${qjackctl_dir}/QtXml" ]; then
            cp -v "${PAWPAW_PREFIX}/lib/QtCore.framework/Versions/5/QtCore" "${qjackctl_dir}/"
            patch_osx_binary_libs "${qjackctl_dir}/QtCore"
            cp -v "${PAWPAW_PREFIX}/lib/QtGui.framework/Versions/5/QtGui" "${qjackctl_dir}/"
            patch_osx_binary_libs "${qjackctl_dir}/QtGui"
            cp -v "${PAWPAW_PREFIX}/lib/QtWidgets.framework/Versions/5/QtWidgets" "${qjackctl_dir}/"
            patch_osx_binary_libs "${qjackctl_dir}/QtWidgets"
            cp -v "${PAWPAW_PREFIX}/lib/QtXml.framework/Versions/5/QtXml" "${qjackctl_dir}/"
            patch_osx_binary_libs "${qjackctl_dir}/QtXml"
        fi
    elif [ "${WIN32}" -eq 1 ]; then
        copy_file qjackctl "${QJACKCTL_VERSION}" "src/release/qjackctl.exe" "${PAWPAW_PREFIX}/jack2/bin/qjackctl.exe"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
