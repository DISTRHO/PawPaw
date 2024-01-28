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

export PAWPAW_SKIP_OPENSSL=1

./bootstrap-common.sh "${target}"
./bootstrap-plugins.sh "${target}"

if [ -z "${PAWPAW_SKIP_QT}" ]; then
    ./bootstrap-python.sh "${target}"
    ./bootstrap-qt.sh "${target}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# file/magic (posix only)

if [ "${WASM}" -eq 0 ] && [ "${WIN32}" -eq 0 ]; then
    download file "${FILE_VERSION}" "${FILE_URL}"
    build_autoconf file "${FILE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# everything after this point requires Qt or PyQt

if [ -n "${PAWPAW_SKIP_QT}" ] && [ "${PAWPAW_SKIP_QT}" -eq 1 ]; then
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------------------
# custom function for sip and pyqt packages

function build_pyqt() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"
    local python="python$(echo ${PYTHON_VERSION} | cut -b 1,2,3)"

    _prebuild "${name}" "${pkgdir}"

    # remove flags not compatible with python
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fno-finite-math-only//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility-inlines-hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-ffast-math//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fno-finite-math-only//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip,-dead_strip_dylibs,-x//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-O1,--gc-sections,--no-undefined//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--as-needed,--strip-all//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"

    # non-standard vars used by sip/pyqt
    export LFLAGS="${LDFLAGS}"
    export LINK="${CXX}"

    # add host/native binaries to path
    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        export PATH="${PAWPAW_PREFIX}-host/bin:${PATH}"
    fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"

        # Place link to Qt DLLs for PyQt tests
        if [ "${WIN32}" -eq 1 ] && [ -d "pyuic" ] && [ ! -d "release" ]; then
            mkdir release
            ln -sf "${PAWPAW_PREFIX}/bin"/Qt* release/
        fi

        ${python} configure.py ${extraconfrules}

        if [ -f "QtCore/Makefile.Release" ]; then
            if [ "${CROSS_COMPILING}" -eq 1 ]; then
                sed -i -e "s|${PAWPAW_PREFIX}-host|${PAWPAW_PREFIX}|" pylupdate5 pyrcc5 pyuic5
            fi
            if [ -n "${EXE_WRAPPER}" ]; then
                sed -i -e "s|exec /|exec ${EXE_WRAPPER} /|" pylupdate5 pyrcc5 pyuic5
            fi
        fi

        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"

        # build sip as host tool first
        if [ "${CROSS_COMPILING}" -eq 1 ] && [ -d "sipgen" ] && [ ! -f "sipgen/sip" ]; then
            pushd "sipgen"
            PATH="${OLD_PATH}" make sip CC="gcc" CFLAGS= LINK="gcc" LFLAGS="-Wl,-s" ${MAKE_ARGS}
            popd
        fi

#         CC="${TARGET_CC}" CXX="${TARGET_CXX}" LFLAGS="${LDFLAGS}" LINK="${TARGET_CXX}" PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}"
        make ${MAKE_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
#         PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}"
        make ${MAKE_ARGS} -j 1 install
        touch .stamp_installed
        popd
    fi

    unset LFLAGS
    unset LINK
}

# ---------------------------------------------------------------------------------------------------------------------
# sip

if [ "${SIP_VERSION}" = "4.19.19" ]; then
    SIP_DOWNLOAD_URL="https://files.kde.org/krita/build/dependencies"
    SIP_EXTRAFLAGS="--sip-module PyQt5.sip"
else
    SIP_DOWNLOAD_URL="http://sourceforge.net/projects/pyqt/files/sip/sip-${SIP_VERSION}"
fi

if [ "${WIN32}" -eq 1 ]; then
    SIP_EXTRAFLAGS+=" --platform win32-g++"
    SIP_EXTRAFLAGS+=" EXTENSION_PLUGIN=pyd"
fi

SIP_EXTRAFLAGS+=" --sysroot=${PAWPAW_PREFIX}"
SIP_EXTRAFLAGS+=" INCDIR=${PAWPAW_PREFIX}/include/python3.8"
SIP_EXTRAFLAGS+=" LIBDIR=${PAWPAW_PREFIX}/lib/python3.8/config-3.8"

download sip "${SIP_VERSION}" "${SIP_DOWNLOAD_URL}"
build_pyqt sip "${SIP_VERSION}" "${SIP_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# pyqt5

if [ "${PYQT5_VERSION}" = "5.13.1" ]; then
    PYQT5_DOWNLOAD_URL="https://files.kde.org/krita/build/dependencies"
    PYQT5_SUFFIX="_gpl"
else
    PYQT5_DOWNLOAD_URL="http://sourceforge.net/projects/pyqt/files/PyQt5/PyQt-${PYQT5_VERSION}"
    PYQT5_SUFFIX="_gpl"
fi

# qmake needs this
if [ "${CROSS_COMPILING}" -eq 1 ]; then
    export PKG_CONFIG_LIBDIR="${TARGET_PKG_CONFIG_PATH}"
    export PKG_CONFIG_SYSROOT_DIR="/"
fi

PYQT5_EXTRAFLAGS="--qmake ${PAWPAW_PREFIX}/bin/qmake --sip ${PAWPAW_PREFIX}/bin/sip --sysroot ${PAWPAW_PREFIX}"

download PyQt5${PYQT5_SUFFIX} "${PYQT5_VERSION}" "${PYQT5_DOWNLOAD_URL}"
build_pyqt PyQt5${PYQT5_SUFFIX} "${PYQT5_VERSION}" "${PYQT5_EXTRAFLAGS} --concatenate --confirm-license"
# --verbose

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_SYSROOT_DIR
fi

# ---------------------------------------------------------------------------------------------------------------------
# pyliblo

if [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 liblo)"
    export EXTRA_LDFLAGS="-shared $(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 liblo)"
    export LDSHARED="${TARGET_CXX}"
fi

download pyliblo "${PYLIBLO_VERSION}" "http://das.nasophon.de/download"
build_python pyliblo "${PYLIBLO_VERSION}"

if [ "${WIN32}" -eq 1 ]; then
    unset LDSHARED
fi

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/liblo.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pyliblo-*.egg/*.so "${PYTHONPATH}/liblo.pyd"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
