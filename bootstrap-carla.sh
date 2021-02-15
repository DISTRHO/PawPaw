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
        extraconfrules+=" --host=${TOOLCHAIN_PREFIX} --build=$(gcc -dumpmachine)"
    fi

    _prebuild "${name}" "${pkgdir}"

    # remove flags not compatible with python
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip -Wl,-dead_strip_dylibs//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--strip-all//')"
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
            # inject exe-wrapper
            if [ -n "${EXE_WRAPPER}" ]; then
                sed -i -e "s|\t./Programs/_freeze_importlib|\t${EXE_WRAPPER} ./Programs/_freeze_importlib|" Makefile
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
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--strip-all//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--gc-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"

    if [ "${WIN32}" -eq 1 ]; then
        export CXXFLAGS+=" -Wno-deprecated-copy"
    fi

    # non-standard vars used by sip/pyqt
    export LFLAGS="${LDFLAGS}"
    export LINK="${CXX}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"

        local python="python$(echo ${PYTHON_VERSION} | cut -b 1,2,3)"

        # Place link to Qt DLLs for PyQt tests
        if [ "${WIN32}" -eq 1 ] && [ -d "pyuic" ] && [ ! -d "release" ]; then
            mkdir release
            ln -sf "${PAWPAW_PREFIX}/bin"/Qt* release/
        fi

        ${python} configure.py ${extraconfrules}

        if [ "${CROSS_COMPILING}" -eq 1 ]; then
            # use abstract python3 path
            sed -i -e 's|/usr/bin/python3|python3|g' Makefile

            # use PREFIX var
            sed -i -e "s|/usr|${PAWPAW_PREFIX}|g" installed.txt Makefile */Makefile
            if [ -f "QtCore/Makefile.Release" ]; then
                sed -i -e "s|/usr|${PAWPAW_PREFIX}|g" */Makefile.Release
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
            PATH="${OLD_PATH}" make sip CC="gcc" LINK="gcc" LFLAGS="-Wl,-s" ${MAKE_ARGS}
            popd
        fi

        make PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}" ${MAKE_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}" ${MAKE_ARGS} -j 1 install
        if [ -f "QtCore/Makefile.Release" ]; then
            if [ "${CROSS_COMPILING}" -eq 1 ]; then
                sed -i -e "s|/usr|${PAWPAW_PREFIX}|g" "${PAWPAW_PREFIX}/bin"/py*5
            fi
            if [ -n "${EXE_WRAPPER}" ]; then
                sed -i -e "s|exec /|exec ${EXE_WRAPPER} /|" "${PAWPAW_PREFIX}/bin"/py*5
            fi
        else
            if [ "${CROSS_COMPILING}" -eq 1 ]; then
                sed -i -e "s|/usr|${PAWPAW_PREFIX}|g" "${PAWPAW_PREFIX}/lib/python3/dist-packages/sipconfig.py"
            fi
        fi
        touch .stamp_installed
        popd
    fi

    unset LFLAGS
    unset LINK
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
# wine bootstrap for python (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ]; then
    env WINEARCH="${PAWPAW_TARGET}" WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
# python

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    PYTHON_EXTRAFLAGS="--enable-optimizations"
#     PYTHON_EXTRAFLAGS+=" ac_cv_lib_intl_textdomain=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_setlocale=no"
elif [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS=" -fwrapv -D__USE_MINGW_ANSI_STDIO=1 -D_WIN32_WINNT=0x0601"
    export EXTRA_CXXFLAGS=" -fwrapv -D__USE_MINGW_ANSI_STDIO=1 -D_WIN32_WINNT=0x0601"
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
    SIP_EXTRAFLAGS+=" INCDIR=${PAWPAW_PREFIX}/include/python3.8"
    SIP_EXTRAFLAGS+=" LIBDIR=${PAWPAW_PREFIX}/lib/python3.8/config-3.8"
fi

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

PYQT5_EXTRAFLAGS="--qmake ${PAWPAW_PREFIX}/bin/qmake --sip ${PAWPAW_PREFIX}/bin/sip"

download PyQt5${PYQT5_SUFFIX} "${PYQT5_VERSION}" "${PYQT5_DOWNLOAD_URL}"
build_pyqt PyQt5${PYQT5_SUFFIX} "${PYQT5_VERSION}" "${PYQT5_EXTRAFLAGS} --concatenate --confirm-license"

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
    export PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
fi

download pyliblo "${PYLIBLO_VERSION}" "http://das.nasophon.de/download"
build_python pyliblo "${PYLIBLO_VERSION}"

if [ "${WIN32}" -eq 1 ]; then
    if [ "${CROSS_COMPILING}" -eq 1 ] && [ ! -e "${PYTHONPATH}/liblo.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pyliblo-*.egg/*.so "${PYTHONPATH}/liblo.pyd"
    fi
    unset LDSHARED
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
if [ "${WIN32}" -eq 1 ]; then
    export PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
fi

build_python cx_Freeze "${CXFREEZE_VERSION}"

if [ "${WIN32}" -eq 1 ]; then
    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        if [ ! -e "${PYTHONPATH}/cx_Freeze" ]; then
            ln -sv "${PYTHONPATH}"/cx_Freeze-*.egg/cx_Freeze "${PYTHONPATH}/cx_Freeze"
        fi
        if [ ! -e "${PYTHONPATH}/cx_Freeze/util.pyd" ]; then
            ln -sv "$(realpath "${PYTHONPATH}/cx_Freeze"/util.*)" "${PYTHONPATH}/cx_Freeze/util.pyd"
        fi
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
