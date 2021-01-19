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
./bootstrap-qt.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# custom function as needed for pyqt packages

function build_conf_python() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules+=" --host=${TOOLCHAIN_PREFIX} --build=x86_64-linux-gnu"
    fi

    _prebuild "${name}" "${pkgdir}"

    # remove flags not compatible with python
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip -Wl,-dead_strip_dylibs//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"

    if [ ! -f "${pkgdir}/.stamp_preconfigured" ] && [ "${WIN32}" -eq 1 ]; then
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
        if [ "${WIN32}" -eq 1 ]; then
            # adds -Wl,-Bdynamic so we link to shared python lib
            sed -i -e 's|BLDLIBRARY=     -L.|BLDLIBRARY=     -Wl,-Bdynamic -L.|' Makefile
            # EXE suffix missing
            sed -i -e 's|./Programs/_freeze_importlib zipimport|./Programs/_freeze_importlib$(EXE) zipimport|' Makefile
            # inject exe-wrapper
            if [ -n "${EXE_WRAPPER}" ]; then
                sed -i -e "s|\t./Programs/_freeze_importlib|\t${EXE_WRAPPER} ./Programs/_freeze_importlib|" Makefile
            fi
            # use toolchain prefix on windres tool if cross-compiling
            if [ "${CROSS_COMPILING}" -eq 1 ]; then
                sed -i -e "s|\twindres|\t${TOOLCHAIN_PREFIX_}windres|" Makefile
            fi
            make regen-importlib
        fi
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

function build_pyqt() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

    # remove flags not compatible with python
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-ffast-math//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility-inlines-hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip -Wl,-dead_strip_dylibs//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ${EXE_WRAPPER} "${PAWPAW_PREFIX}/bin/python3${APP_EXT}" configure.py ${extraconfrules}
        # use env vars
        sed -i -e 's/CC = gcc/CC ?= gcc/' */Makefile
        sed -i -e 's/CXX = g++/CXX ?= g++/' */Makefile
        sed -i -e 's/LINK = g++/LINK = $(CXX)/' */Makefile
        sed -i -e 's/CFLAGS *=/CFLAGS +=/' */Makefile
        sed -i -e 's/CXXFLAGS *=/CXXFLAGS +=/' */Makefile
        sed -i -e 's/LIBS *=/LIBS += $(LDFLAGS)/' */Makefile
        # use PREFIX var
        sed -i -e 's|$(DESTDIR)/usr|$(DESTDIR)$(PREFIX)|g' */Makefile
        # fix win32 linkage
        if [ "${WIN32}" -eq 1 ]; then
            sed -i -e 's|config -lpython|config-3.8 -Wl,-Bdynamic -lpython|' */Makefile
        fi
        # fix cross-compiling (wine)
        if [ "${CROSS_COMPILING}" -eq 1 ]; then
            sed -i -e 's|\\|/|g' Makefile */Makefile installed.txt
            sed -i -e "s|H:|${HOME}|g" Makefile */Makefile installed.txt
            sed -i -e "s|Z:||g" Makefile */Makefile installed.txt
            sed -i -e "s|.exe.exe|.exe|g" installed.txt
            sed -i -e "s|${PAWPAW_PREFIX}/bin/python3${APP_EXT}|python3|" Makefile */Makefile
        fi
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}" ${MAKE_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}" ${MAKE_ARGS} -j 1 install
        touch .stamp_installed
        popd
    fi
}

# ---------------------------------------------------------------------------------------------------------------------
# file/magic (posix only)

if [ "${WIN32}" -eq 0 ]; then
    download file "${FILE_VERSION}" "ftp://ftp.astron.com/pub/file"
    build_autoconf file "${FILE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libffi (for python, not needed in macOS)

if [ "${MACOS}" -eq 0 ]; then
    download libffi "${LIBFFI_VERSION}" "https://sourceware.org/pub/libffi"
    build_autoconf libffi "${LIBFFI_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# python

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    PYTHON_EXTRAFLAGS="--enable-optimizations"
elif [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS=" -fwrapv -D__USE_MINGW_ANSI_STDIO=1 -D_WIN32_WINNT=0x0601"
    export EXTRA_CXXFLAGS=" -fwrapv -D__USE_MINGW_ANSI_STDIO=1 -D_WIN32_WINNT=0x0601"
    PYTHON_EXTRAFLAGS="--with-nt-threads"
    PYTHON_EXTRAFLAGS+=" --without-ensurepip"
    PYTHON_EXTRAFLAGS+=" --without-c-locale-coercion"
    # PYTHON_EXTRAFLAGS+=" --enable-optimizations"
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
    PYTHON_EXTRAFLAGS+=" OPT="
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
fi

download sip "${SIP_VERSION}" "${SIP_DOWNLOAD_URL}"
build_pyqt sip "${SIP_VERSION}" "${SIP_EXTRAFLAGS}"

# TODO: finish this
if [ "${WIN32}" -eq 1 ]; then
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------------------
# pyqt5

if [ "${PYQT5_VERSION}" = "5.13.1" ]; then
    PYQT5_DOWNLOAD_URL="https://files.kde.org/krita/build/dependencies"
    PYQT5_SUFFIX="_gpl"
else
    PYQT5_DOWNLOAD_URL="http://sourceforge.net/projects/pyqt/files/PyQt5/PyQt-${PYQT5_VERSION}"
    PYQT5_SUFFIX="_gpl"
fi

download PyQt5${PYQT5_SUFFIX} "${PYQT5_VERSION}" "${PYQT5_DOWNLOAD_URL}"
build_pyqt PyQt5${PYQT5_SUFFIX} "${PYQT5_VERSION}" "--concatenate --confirm-license -c"

# ---------------------------------------------------------------------------------------------------------------------
# cython (optional)

if [ -n "${CYTHON_VERSION}" ]; then
    download Cython "${CYTHON_VERSION}" "https://files.pythonhosted.org/packages/6c/9f/f501ba9d178aeb1f5bf7da1ad5619b207c90ac235d9859961c11829d0160"
    build_python Cython "${CYTHON_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# pyliblo

download pyliblo "${PYLIBLO_VERSION}" "http://das.nasophon.de/download"
build_python pyliblo "${PYLIBLO_VERSION}"

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
    download importlib_metadata "${IMPORTLIB_METADATA_VERSION}" "https://files.pythonhosted.org/packages/3f/a8/16dc098b0addd1c20719c18a86e985be851b3ec1e103e703297169bb22cc"
    build_python importlib_metadata "${IMPORTLIB_METADATA_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# cxfreeze

download cx_Freeze "${CXFREEZE_VERSION}" "https://github.com/anthony-tuininga/cx_Freeze/archive" "" "nv"
if [ "${CXFREEZE_VERSION}" = "6.4.2" ]; then
    patch_file cx_Freeze "${CXFREEZE_VERSION}" "setup.py" 's/extra_postargs=extraArgs,/extra_postargs=extraArgs+os.getenv("LDFLAGS").split(),/'
    patch_file cx_Freeze "${CXFREEZE_VERSION}" "cx_Freeze/macdist.py" 's/, use_builtin_types=False//'
fi
build_python cx_Freeze "${CXFREEZE_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
