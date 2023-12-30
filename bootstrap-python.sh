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
# check for depedencies

if [ "${LINUX}" -eq 1 ] && ! command -v patchelf >/dev/null; then
    echo "missing 'patchelf' program, cannot continue!"
    exit 2
fi

# ---------------------------------------------------------------------------------------------------------------------
# wine bootstrap for python (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
# custom function for openssl

function build_conf_openssl() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"
    local extraflags=""

    if [ -n "${TOOLCHAIN_PREFIX}" ]; then
        if [ "${WIN64}" -eq 1 ]; then
            export MACHINE="x86_64"
            export SYSTEM="mingw64"
            extraflags="-Wa,-mbig-obj"
        elif [ "${WIN32}" -eq 1 ]; then
            export MACHINE="i686"
            export SYSTEM="mingw"
        elif [ -n "${LINUX_TARGET}" ]; then
            if [ "${LINUX_TARGET}" = "linux-armhf" ]; then
                export MACHINE="armv4"
            elif [ "${LINUX_TARGET}" = "linux-aarch64" ]; then
                export MACHINE="aarch64"
            elif [ "${LINUX_TARGET}" = "linux-i686" ]; then
                export MACHINE="i686"
            elif [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
                export MACHINE="riscv64"
            elif [ "${LINUX_TARGET}" = "linux-x86_64" ]; then
                export MACHINE="x86_64"
            else
                export MACHINE="$(uname -m)"
            fi
            export SYSTEM="linux2"
        fi
        export RELEASE="whatever"
        export BUILD="unknown"
    elif [ "${MACOS_UNIVERSAL}" -eq 0 ] && [ "$(uname -m)" != "x86_64" ]; then
        export MACHINE="x86_64"
    fi

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./config --prefix="${PAWPAW_PREFIX}" ${extraconfrules} CFLAGS="${TARGET_CFLAGS} ${extraflags}"
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        make ${MAKE_ARGS} ${EXTRA_MAKE_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make ${MAKE_ARGS} install_sw -j 1
        touch .stamp_installed
        popd
    fi

    if [ -n "${TOOLCHAIN_PREFIX}" ]; then
        unset MACHINE
        unset SYSTEM
        unset RELEASE
        unset BUILD
    fi

    _postbuild
}

# ---------------------------------------------------------------------------------------------------------------------
# openssl

if [ -z "${PAWPAW_SKIP_OPENSSL}" ]; then

OPENSSL_URL="https://www.openssl.org/source"
OPENSSL_VERSION="1.1.1w"

OPENSSL_EXTRAFLAGS="no-capieng no-pinshared no-shared no-hw no-zlib threads"
if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    OPENSSL_EXTRAFLAGS+=" no-asm"
fi

download openssl "${OPENSSL_VERSION}" "${OPENSSL_URL}"
build_conf_openssl openssl "${OPENSSL_VERSION}" "${OPENSSL_EXTRAFLAGS}"

fi # PAWPAW_SKIP_OPENSSL

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
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-O1,--gc-sections,--no-undefined//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--as-needed,--strip-all//')"
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

PYTHON_EXTRAFLAGS=""

if [ "${MACOS}" -eq 1 ]; then
    PYTHON_EXTRAFLAGS+=" --enable-optimizations"
    PYTHON_EXTRAFLAGS+=" ac_cv_lib_intl_textdomain=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_header_libintl_h=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_setlocale=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_futimens=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_preadv=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_pwritev=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_sendfile=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_func_utimensat=no"
elif [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS=" -fwrapv -D_WIN32_WINNT=0x0601"
    export EXTRA_CXXFLAGS=" -fwrapv -D_WIN32_WINNT=0x0601"
    PYTHON_EXTRAFLAGS+=" --with-nt-threads"
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
elif [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHON_EXTRAFLAGS+=" --disable-ipv6"
    PYTHON_EXTRAFLAGS+=" ac_cv_file__dev_ptc=no"
    PYTHON_EXTRAFLAGS+=" ac_cv_file__dev_ptmx=no"
fi

download Python "${PYTHON_VERSION}" "https://www.python.org/ftp/python/${PYTHON_VERSION}" "tgz"
if [ "${PYTHON_VERSION}" = "3.7.4" ]; then
    patch_file Python "${PYTHON_VERSION}" "Modules/Setup.dist" 's/#zlib zlibmodule.c/zlib zlibmodule.c/'
fi
build_conf_python Python "${PYTHON_VERSION}" "--prefix=${PAWPAW_PREFIX} --enable-shared ${PYTHON_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# cython (optional)

if [ -n "${CYTHON_VERSION}" ]; then
    download Cython "${CYTHON_VERSION}" "https://files.pythonhosted.org/packages/6c/9f/f501ba9d178aeb1f5bf7da1ad5619b207c90ac235d9859961c11829d0160"
    build_python Cython "${CYTHON_VERSION}"
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
