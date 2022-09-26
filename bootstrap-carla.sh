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
./bootstrap-plugins.sh "${target}"

if [ -z "${PAWPAW_SKIP_QT}" ]; then
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

if [ -n "${PAWPAW_SKIP_QT}" ]; then
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------------------
# custom function for python

function build_conf_python() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ -n "${TOOLCHAIN_PREFIX}" ]; then
        extraconfrules+=" --host=${TOOLCHAIN_PREFIX} --build=$(gcc -dumpmachine)"
    fi

    _prebuild "${name}" "${pkgdir}"

    # remove flags not compatible with python
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip,-dead_strip_dylibs,-x//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-O1,--as-needed,--gc-sections,--no-undefined,--strip-all//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"

    # add host/native binaries to path
    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        export PATH="${PAWPAW_PREFIX}-host/bin:${PATH}"
    fi

    if [ "${WIN32}" -eq 1 ] && [ ! -f "${pkgdir}/.stamp_preconfigured" ]; then
        pushd "${pkgdir}"
        autoreconf -vfi
        touch .stamp_preconfigured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./configure ${extraconfrules}
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
#         if [ "${WIN32}" -eq 1 ]; then
#             # inject exe-wrapper
#             if [ -n "${EXE_WRAPPER}" ]; then
#                 sed -i -e "s|\t./Programs/_freeze_importlib|\t${EXE_WRAPPER} ./Programs/_freeze_importlib|" Makefile
#             fi
#             make regen-importlib
#         fi
        make ${MAKE_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make ${MAKE_ARGS} -j 1 install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

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
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility-inlines-hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-ffast-math//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip,-dead_strip_dylibs,-x//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-O1,--as-needed,--gc-sections,--no-undefined,--strip-all//')"
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
# wine bootstrap for python (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
# python

# build for host first
if [ "${CROSS_COMPILING}" -eq 1 ]; then
    download host-Python "${PYTHON_VERSION}" "https://www.python.org/ftp/python/${PYTHON_VERSION}" "tgz" "" Python
    build_host_autoconf host-Python "${PYTHON_VERSION}" "--build=$(gcc -dumpmachine) --prefix=${PAWPAW_PREFIX}-host"

    # sed -i -e "s|${PAWPAW_PREFIX}-host|${PAWPAW_PREFIX}|" "${PAWPAW_PREFIX}-host/bin/python3.8-config"

#     # FIXME
#     mkdir -p "${PAWPAW_PREFIX}-host/lib/python3.8/config-3.8-x86_64-linux-gnu/Tools"
#     ln -sf "${PAWPAW_PREFIX}-host/bin" "${PAWPAW_PREFIX}-host/lib/python3.8/config-3.8-x86_64-linux-gnu/Tools/scripts"

#     # may be available in host, but not in build target
#     if [ "${WIN32}" -eq 1 ] && [ ! -e "${PAWPAW_PREFIX}-host/include/python3.8/pyconfig.h-e" ]; then
#         sed -i -e '/HAVE_CRYPT_H/d' "${PAWPAW_PREFIX}-host/include/python3.8/pyconfig.h"
#         sed -i -e '/HAVE_CRYPT_R/d' "${PAWPAW_PREFIX}-host/include/python3.8/pyconfig.h"
#         sed -i -e '/HAVE_SYS_SELECT_H/d' "${PAWPAW_PREFIX}-host/include/python3.8/pyconfig.h"
#         touch "${PAWPAW_PREFIX}-host/include/python3.8/pyconfig.h-e"
#     fi
fi

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    PYTHON_EXTRAFLAGS="--enable-optimizations"
    PYTHON_EXTRAFLAGS+=" ac_cv_lib_intl_textdomain=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_header_libintl_h=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_setlocale=no"
elif [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS=" -fwrapv -D_WIN32_WINNT=0x0601"
    export EXTRA_CXXFLAGS=" -fwrapv -D_WIN32_WINNT=0x0601"
    PYTHON_EXTRAFLAGS="--with-nt-threads"
    PYTHON_EXTRAFLAGS+=" --without-ensurepip"
    PYTHON_EXTRAFLAGS+=" --without-c-locale-coercion"
    # Workaround for conftest error on 64-bit builds
    PYTHON_EXTRAFLAGS+=" ac_cv_working_tzset=no"
    # Workaround for when dlfcn exists on Windows, which causes
    # some conftests to succeed when they shouldn't (we don't use dlfcn).
    PYTHON_EXTRAFLAGS+=" ac_cv_header_dlfcn_h=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_lib_dl_dlopen=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_GLOBAL=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_LAZY=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_LOCAL=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_NOW=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_DEEPBIND=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_MEMBER=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_NODELETE=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_have_decl_RTLD_NOLOAD=no"
fi

download Python "${PYTHON_VERSION}" "https://www.python.org/ftp/python/${PYTHON_VERSION}" "tgz"
if [ "${PYTHON_VERSION}" = "3.7.4" ]; then
    patch_file Python "${PYTHON_VERSION}" "Modules/Setup.dist" 's/#zlib zlibmodule.c/zlib zlibmodule.c/'
fi
build_conf_python Python "${PYTHON_VERSION}" "--prefix=${PAWPAW_PREFIX} --enable-shared ${PYTHON_EXTRAFLAGS}"

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
# cython (optional)

if [ -n "${CYTHON_VERSION}" ]; then
    download Cython "${CYTHON_VERSION}" "https://files.pythonhosted.org/packages/6c/9f/f501ba9d178aeb1f5bf7da1ad5619b207c90ac235d9859961c11829d0160"
    build_python Cython "${CYTHON_VERSION}"
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
    if [ "${CROSS_COMPILING}" -eq 1 ] && [ ! -e "${PYTHONPATH}/liblo.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pyliblo-*.egg/*.so "${PYTHONPATH}/liblo.pyd"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
# setuptools_scm (optional)

if [ -n "${SETUPTOOLS_SCM_VERSION}" ]; then
    download setuptools_scm "${SETUPTOOLS_SCM_VERSION}" "https://files.pythonhosted.org/packages/ed/b6/979bfa7b81878b2b4475dde092aac517e7f25dd33661796ec35664907b31"
    build_python setuptools_scm "${SETUPTOOLS_SCM_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# toml (optional)

if [ -n "${TOML_VERSION}" ]; then
    download toml "${TOML_VERSION}" "https://files.pythonhosted.org/packages/be/ba/1f744cdc819428fc6b5084ec34d9b30660f6f9daaf70eead706e3203ec3c"
    build_python toml "${TOML_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# zipp (optional)

if [ -n "${ZIPP_VERSION}" ]; then
    download zipp "${ZIPP_VERSION}" "https://files.pythonhosted.org/packages/ce/b0/757db659e8b91cb3ea47d90350d7735817fe1df36086afc77c1c4610d559"
    build_python zipp "${ZIPP_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# importlib_metadata (optional)

if [ -n "${IMPORTLIB_METADATA_VERSION}" ]; then
    download importlib_metadata "${IMPORTLIB_METADATA_VERSION}" "https://files.pythonhosted.org/packages/f8/41/8ffb059708359ea14a3ec74a99a2bf0cd44a0c983a0c480d9eb7a69438bb"
    build_python importlib_metadata "${IMPORTLIB_METADATA_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# cxfreeze

git_clone cx_Freeze "${CXFREEZE_VERSION}" "https://github.com/anthony-tuininga/cx_Freeze.git"
build_python cx_Freeze "${CXFREEZE_VERSION}"

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/cx_Freeze" ]; then
        ln -sv "${PYTHONPATH}"/cx_Freeze-*.egg/cx_Freeze "${PYTHONPATH}/cx_Freeze"
    fi
    if [ ! -e "${PYTHONPATH}/cx_Freeze/util.pyd" ]; then
        ln -sv "$(realpath "${PYTHONPATH}/cx_Freeze"/util.*)" "${PYTHONPATH}/cx_Freeze/util.pyd"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
