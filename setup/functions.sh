#!/bin/bash

# NOTE `setup/check_target.sh` and `setup/env.sh` must be imported before this one, in that order

# ---------------------------------------------------------------------------------------------------------------------

function download() {
    local pkgname="${1}"
    local version="${2}"
    local dlbaseurl="${3}"
    local dlext="${4}"
    local dlmethod="${5}"
    local dlname="${6}"

    if [ -z "${dlext}" ]; then
        dlext="tar.gz"
    fi
    if [ -z "${dlname}" ]; then
        dlname="${pkgname}"
    fi

    local dlfile="${PAWPAW_DOWNLOADDIR}/${dlname}-${version}.${dlext}"
    local dlfolder="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ ! -f "${dlfile}" ]; then
        if [ -n "${dlmethod}" ] && [ "${dlmethod}" = "git" ]; then
            local tmprepodir="${PAWPAW_TMPDIR}/${dlname}-${version}"
            rm -rf "${tmprepodir}"
            git clone --recursive "${dlbaseurl}" "${tmprepodir}"
            git -C "${tmprepodir}" checkout "${version}"
            git -C "${tmprepodir}" submodule update --recursive --init
            tar --exclude=".git" -czf "${dlfile}" -C "${PAWPAW_TMPDIR}" "${dlname}-${version}"
            rm -rf "${tmprepodir}"
        else
            local dlurl1
            local dlurl2
            if echo ${dlbaseurl} | grep -q github.com | grep -q -v releases; then
                if [ x"${dlmethod}" = x"nv" ]; then
                    dlurl1="${dlbaseurl}/${version}.${dlext}"
                    dlurl2="${KXSTUDIO_FILES_URL}/${version}.${dlext}"
                else
                    dlurl1="${dlbaseurl}/v${version}.${dlext}"
                    dlurl2="${KXSTUDIO_FILES_URL}/v${version}.${dlext}"
                fi
            elif [ "${dlext}" = "orig.tar.gz" ]; then
                dlurl1="${dlbaseurl}/${dlname}_${version}.${dlext}"
                dlurl2="${KXSTUDIO_FILES_URL}/${dlname}_${version}.${dlext}"
            else
                dlurl1="${dlbaseurl}/${dlname}-${version}.${dlext}"
                dlurl2="${KXSTUDIO_FILES_URL}/${dlname}-${version}.${dlext}"
            fi
            echo "Downloading ${dlurl1}"
            curl -L "${dlurl1}" -o "${dlfile}" --fail || curl -L "${dlurl2}" -o "${dlfile}" --fail
        fi
    fi

    if [ ! -d "${dlfolder}" ]; then
        mkdir "${dlfolder}"
        echo "Extracting ${dlfile}"
        file "${dlfile}"
        md5sum "${dlfile}"
        tar -xf "${dlfile}" -C "${dlfolder}" --strip-components=1
    fi
}

function copy_download() {
    local pkgname1="${1}"
    local pkgname2="${2}"
    local version="${3}"
    local dlext="${4}"

    if [ -z "${dlext}" ]; then
        dlext="tar.gz"
    fi

    local dlfile1="${PAWPAW_DOWNLOADDIR}/${pkgname1}-${version}.${dlext}"
    local dlfolder2="${PAWPAW_BUILDDIR}/${pkgname2}-${version}"

    if [ ! -d "${dlfolder2}" ]; then
        mkdir "${dlfolder2}"
        tar -xf "${dlfile1}" -C "${dlfolder2}" --strip-components=1
    fi
}

function git_clone() {
    local pkgname="${1}"
    local hash="${2}"
    local repourl="${3}"
    local dlname="${4}"

    if [ -z "${dlname}" ]; then
        dlname="${pkgname}"
    fi

    local dlfile="${PAWPAW_DOWNLOADDIR}/${dlname}-${hash}.tar.gz"
    local dlfolder="${PAWPAW_BUILDDIR}/${pkgname}-${hash}"

    if [ ! -f "${dlfile}" ]; then
        local tmprepodir="${PAWPAW_TMPDIR}/${dlname}-${hash}"
        rm -rf "${tmprepodir}"
        git clone --recursive "${repourl}" "${tmprepodir}"
        git -C "${tmprepodir}" checkout "${hash}"
        git -C "${tmprepodir}" submodule update --recursive --init
        tar --exclude=".git" -czf "${dlfile}" -C "${PAWPAW_TMPDIR}" "${dlname}-${hash}"
        rm -rf "${tmprepodir}"
    fi

    if [ ! -d "${dlfolder}" ]; then
        mkdir "${dlfolder}"
        tar -xf "${dlfile}" -C "${dlfolder}" --strip-components=1
    fi
}

# ---------------------------------------------------------------------------------------------------------------------

function _prebuild() {
    local pkgname="${1}"
    local pkgdir="${2}"

    export AR="${TARGET_AR}"
    export CC="${TARGET_CC}"
    export CXX="${TARGET_CXX}"
    export DLLWRAP="${TARGET_DLLWRAP}"
    export LD="${TARGET_LD}"
    export NM="${TARGET_NM}"
    export RANLIB="${TARGET_RANLIB}"
    export STRIP="${TARGET_STRIP}"
    export WINDRES="${TARGET_WINDRES}"

    export CFLAGS="${TARGET_CFLAGS} ${EXTRA_CFLAGS}"
    export CXXFLAGS="${TARGET_CXXFLAGS} ${EXTRA_CXXFLAGS}"
    export LDFLAGS="${TARGET_LDFLAGS} ${EXTRA_LDFLAGS}"
    export PKG_CONFIG_PATH="${TARGET_PKG_CONFIG_PATH}"

    if [ -n "${EXTRA_CPPFLAGS}" ]; then
        export CPPFLAGS="${EXTRA_CPPFLAGS}"
    else
        unset CPPFLAGS
    fi

    export OLD_PATH="${PATH}"
    export PATH="${TARGET_PATH}"

    if [ -e "${PAWPAW_ROOT}/patches/${pkgname}" ] && [ ! -f "${pkgdir}/.stamp_cleanup" ] && [ ! -f "${pkgdir}/.stamp_configured" ]; then
        local patchtargets="${PAWPAW_TARGET}"
        if [[ "${PAWPAW_TARGET}" = "linux-"* ]]; then
            patchtargets+=" linux"
        elif [ "${PAWPAW_TARGET}" = "macos-universal-10.15" ]; then
            patchtargets+=" macos-10.15 macos-universal"
        elif [ "${PAWPAW_TARGET}" = "win64" ]; then
            patchtargets+=" win32"
        fi

        for target in ${patchtargets[@]}; do
            if [ -e "${PAWPAW_ROOT}/patches/${pkgname}/${target}" ]; then
                for p in $(ls "${PAWPAW_ROOT}/patches/${pkgname}/${target}/" | grep "\.patch$" | sort); do
                    if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                        patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${pkgname}/${target}/${p}"
                        touch "${pkgdir}/.stamp_applied_${p}"
                    fi
                done
            fi
        done

        for p in $(ls "${PAWPAW_ROOT}/patches/${pkgname}/" | grep "\.patch$" | sort); do
            if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${pkgname}/${p}"
                touch "${pkgdir}/.stamp_applied_${p}"
            fi
        done
    fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        rm -f "${pkgdir}/.stamp_built"
        rm -f "${pkgdir}/.stamp_installed"
        rm -f "${pkgdir}/.stamp_verified"
        rm -f "${pkgdir}/CMakeCache.txt"

    elif [ ! -f "${pkgdir}/.stamp_built" ]; then
        rm -f "${pkgdir}/.stamp_installed"
        rm -f "${pkgdir}/.stamp_verified"

    elif [ ! -f "${pkgdir}/.stamp_installed" ]; then
        rm -f "${pkgdir}/.stamp_verified"

    fi
}

function _postbuild() {
    unset AR
    unset CC
    unset CXX
    unset DLLWRAP
    unset LD
    unset NM
    unset RANLIB
    unset STRIP
    unset WINDRES

    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset PKG_CONFIG_PATH

    unset EXTRA_CFLAGS
    unset EXTRA_CPPFLAGS
    unset EXTRA_CXXFLAGS
    unset EXTRA_LDFLAGS
    unset EXTRA_MAKE_ARGS

    export PATH="${OLD_PATH}"
}

# ---------------------------------------------------------------------------------------------------------------------

function build_autoconf() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ "${LINUX}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
        extraconfrules+=" --build=$(uname -m)-linux-gnu ac_cv_build=$(uname -m)-linux-gnu"
    fi

    if [ "${LINUX}" -eq 1 ] && [ "$(uname -m)" != "x86_64" ]; then
        extraconfrules+=" --host=$(uname -m)-linux-gnu ac_cv_host=$(uname -m)-linux-gnu"
    elif [ "${WASM}" -eq 1 ]; then
        extraconfrules+=" --host=i686-linux-gnu ac_cv_host=i686-linux-gnu"
    elif [ -n "${TOOLCHAIN_PREFIX}" ]; then
        extraconfrules+=" --host=${TOOLCHAIN_PREFIX} ac_cv_host=${TOOLCHAIN_PREFIX}"
    fi

    if echo "${extraconfrules}" | grep -q -e '--enable-debug' -e '--disable-debug'; then
        true
    elif [ -n "${PAWPAW_DEBUG}" ] && [ "${PAWPAW_DEBUG}" -eq 1 ]; then
        extraconfrules+=" --enable-debug"
    else
        extraconfrules+=" --disable-debug"
    fi

    _prebuild "${pkgname}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./configure --enable-static --disable-shared --disable-doc --disable-docs --disable-maintainer-mode --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
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
        make ${MAKE_ARGS} install -j 1
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_autoconfgen() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    local EXTRA_CFLAGS2="${EXTRA_CFLAGS}"
    local EXTRA_CXXFLAGS2="${EXTRA_CXXFLAGS}"
    local EXTRA_LDFLAGS2="${EXTRA_LDFLAGS}"
    local EXTRA_MAKE_ARGS2="${EXTRA_MAKE_ARGS}"

    _prebuild "${pkgname}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_preconfigured" ]; then
        pushd "${pkgdir}"
        if [ -f utils/autogen.sh ]; then
            ./utils/autogen.sh
        else
            ${autoconf}
        fi
        touch .stamp_preconfigured
        popd
    fi

    _postbuild

    export EXTRA_CFLAGS="${EXTRA_CFLAGS2}"
    export EXTRA_CXXFLAGS="${EXTRA_CXXFLAGS2}"
    export EXTRA_LDFLAGS="${EXTRA_LDFLAGS2}"
    export EXTRA_MAKE_ARGS="${EXTRA_MAKE_ARGS2}"

    build_autoconf "${pkgname}" "${version}" "${extraconfrules}"
}

function build_conf() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    _prebuild "${pkgname}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./configure ${extraconfrules}
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
        make ${MAKE_ARGS} -j 1 install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_cmake() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    _prebuild "${pkgname}" "${pkgdir}"
    mkdir -p "${pkgdir}/build"

    if [ "${WASM}" -eq 1 ]; then
        CMAKE_EXE_WRAPPER="emcmake"
    elif [ "${CROSS_COMPILING}" -eq 1 ]; then
        local CMAKE_AR=$(which ${TARGET_AR})
        local CMAKE_RANLIB=$(which ${TARGET_RANLIB})
        extraconfrules+=" -DCMAKE_CROSSCOMPILING=ON"
        extraconfrules+=" -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}"
        extraconfrules+=" -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}"
        extraconfrules+=" -DCMAKE_AR=${CMAKE_AR}"
        extraconfrules+=" -DCMAKE_C_COMPILER_AR=${CMAKE_AR}"
        extraconfrules+=" -DCMAKE_CXX_COMPILER_AR=${CMAKE_AR}"
        extraconfrules+=" -DCMAKE_RANLIB=${CMAKE_RANLIB}"
        extraconfrules+=" -DCMAKE_C_COMPILER_RANLIB=${CMAKE_RANLIB}"
        extraconfrules+=" -DCMAKE_CXX_COMPILER_RANLIB=${CMAKE_RANLIB}"
        if [ -n "${EXE_WRAPPER}" ]; then
            extraconfrules+=" -DCMAKE_CROSSCOMPILING_EMULATOR=${EXE_WRAPPER}"
        fi
    fi

    if [ "${MACOS}" -eq 1 ]; then
        extraconfrules+=" -DCMAKE_OSX_SYSROOT=macosx"
        if [ "${MACOS_10_15}" -eq 1 ]; then
            extraconfrules+=" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15"
        elif [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
            extraconfrules+=" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12"
        else
            extraconfrules+=" -DCMAKE_OSX_DEPLOYMENT_TARGET=10.8"
        fi
        if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
            extraconfrules+=" -DCMAKE_OSX_ARCHITECTURES='arm64;x86_64'"
        else
            extraconfrules+=" -DCMAKE_OSX_ARCHITECTURES=x86_64"
        fi
    elif [ "${WIN32}" -eq 1 ]; then
        extraconfrules+=" -DCMAKE_RC_COMPILER=${WINDRES}"
    fi

    if [ -n "${PAWPAW_DEBUG}" ] && [ "${PAWPAW_DEBUG}" -eq 1 ]; then
        extraconfrules+=" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_DEBUG_POSTFIX="
    else
        extraconfrules+=" -DCMAKE_BUILD_TYPE=Release"
    fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}/build"
        ${CMAKE_EXE_WRAPPER} ${cmake} -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_PREFIX="${PAWPAW_PREFIX}" ${extraconfrules} ..
        touch ../.stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}/build"
        make ${MAKE_ARGS} ${EXTRA_MAKE_ARGS}
        touch ../.stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}/build"
        make ${MAKE_ARGS} -j 1 install
        touch ../.stamp_installed
        popd
    fi

    _postbuild
}

function build_make() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    _prebuild "${pkgname}" "${pkgdir}"

    touch "${pkgdir}/.stamp_configured"

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}" ${MAKE_ARGS} ${extraconfrules}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" PKG_CONFIG="${TARGET_PKG_CONFIG}" ${MAKE_ARGS} ${extraconfrules} -j 1 install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_meson() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules+=" --cross-file ${PAWPAW_ROOT}/setup/meson/${PAWPAW_TARGET}.ini"
    fi

    if [ -n "${PAWPAW_DEBUG}" ] && [ "${PAWPAW_DEBUG}" -eq 1 ]; then
        extraconfrules+=" --buildtype debug"
    else
        extraconfrules+=" --buildtype release"
    fi

    _prebuild "${pkgname}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        env NINJA="${ninja}" ${meson} setup build --prefix "${PAWPAW_PREFIX}" --libdir lib ${extraconfrules}
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        ${ninja} -v -C build
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        ${ninja} -C build install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_python() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"
    local python="python$(echo ${PYTHON_VERSION} | cut -b 1,2,3)"

    _prebuild "${pkgname}" "${pkgdir}"

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
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--gc-sections,--no-undefined//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-O1//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,--as-needed,--strip-all//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fno-strict-aliasing -flto//')"

    # add host/native binaries to path
    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        export PATH="${PAWPAW_PREFIX}-host/bin:${PATH}"
    elif [ "${LINUX}" -eq 1 ]; then
        export LD_LIBRARY_PATH="${PAWPAW_PREFIX}/lib"
    fi

    touch "${pkgdir}/.stamp_configured"

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        ${python} setup.py build_ext ${extraconfrules} --verbose
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        # always try twice, python checks for installed deps and fails the first time
        ${python} setup.py install --prefix="${PAWPAW_PREFIX}" --verbose || \
        ${python} setup.py install --prefix="${PAWPAW_PREFIX}" --verbose || true
        touch .stamp_installed
        popd
    fi

    if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${LINUX}" -eq 1 ]; then
        unset LD_LIBRARY_PATH
    fi

    _postbuild
}

function build_qmake() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    _prebuild "${pkgname}" "${pkgdir}"

    # if [ "${CROSS_COMPILING}" -eq 1 ]; then
    #     export PKG_CONFIG_LIBDIR="${TARGET_PKG_CONFIG_PATH}"
    #     export PKG_CONFIG_SYSROOT_DIR="/"
    # fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        qmake ${extraconfrules}
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
        make ${MAKE_ARGS} -j 1 install
        touch .stamp_installed
        popd
    fi

    # unset PKG_CONFIG_LIBDIR
    # unset PKG_CONFIG_SYSROOT_DIR

    _postbuild
}

function build_waf() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"
    local python=python3

    if ! which python3 > /dev/null; then
        python=python
    fi

    if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${LINUX}" -eq 1 ]; then
        export LD_LIBRARY_PATH="${PAWPAW_PREFIX}/lib"
    fi

    _prebuild "${pkgname}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ${python} waf configure --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        ${python} waf build ${WAF_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        ${python} waf install ${WAF_ARGS} --prefix="${PAWPAW_PREFIX}" ${extraconfrules} -j 1
        rm -f ${PAWPAW_PREFIX}/lib/lv2/*/*.a
        touch .stamp_installed
        popd
    fi

    if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${LINUX}" -eq 1 ]; then
        unset LD_LIBRARY_PATH
    fi

    _postbuild
}

# ---------------------------------------------------------------------------------------------------------------------

function run_make() {
    local pkgname="${1}"
    local version="${2}"
    local makerule="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    _prebuild "${pkgname}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_custom_run" ] && [ ! -f "${pkgdir}/.stamp_cleanup" ]; then
        pushd "${pkgdir}"
        make ${MAKE_ARGS} ${makerule}
        touch .stamp_custom_run
        popd
    fi

    _postbuild
}

# ---------------------------------------------------------------------------------------------------------------------

function build_host_autoconf() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    unset AR
    unset CC
    unset CXX
    unset LD
    unset STRIP
    unset CPPFLAGS

    export CFLAGS="${EXTRA_CFLAGS}"
    export CXXFLAGS="${EXTRA_CXXFLAGS}"
    export LDFLAGS="${EXTRA_LDFLAGS}"

    if [ -e "${PAWPAW_ROOT}/patches/${pkgname}" ] && [ ! -f "${pkgdir}/.stamp_cleanup" ] && [ ! -f "${pkgdir}/.stamp_configured" ]; then
        local patchtargets="${PAWPAW_TARGET}"
        if [[ "${PAWPAW_TARGET}" = "linux-"* ]]; then
            patchtargets+=" linux"
        elif [ "${PAWPAW_TARGET}" = "macos-universal-10.15" ]; then
            patchtargets+=" macos-10.15 macos-universal"
        elif [ "${PAWPAW_TARGET}" = "win64" ]; then
            patchtargets+=" win32"
        fi

        for target in ${patchtargets[@]}; do
            if [ -e "${PAWPAW_ROOT}/patches/${pkgname}/${target}" ]; then
                for p in $(ls "${PAWPAW_ROOT}/patches/${pkgname}/${target}/" | grep "\.patch$" | sort); do
                    if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                        patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${pkgname}/${target}/${p}"
                        touch "${pkgdir}/.stamp_applied_${p}"
                    fi
                done
            fi
        done

        for p in $(ls "${PAWPAW_ROOT}/patches/${pkgname}/" | grep "\.patch$" | sort); do
            if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${pkgname}/${p}"
                touch "${pkgdir}/.stamp_applied_${p}"
            fi
        done
    fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./configure --enable-static --disable-shared --disable-maintainer-mode --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        make ${MAKE_ARGS}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make ${MAKE_ARGS} install -j 1
        touch .stamp_installed
        popd
    fi

    unset CFLAGS
    unset CXXFLAGS
    unset LDFLAGS
}

function build_host_cmake() {
    local pkgname="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    unset AR
    unset CC
    unset CXX
    unset LD
    unset STRIP
    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS

    if [ -e "${PAWPAW_ROOT}/patches/${pkgname}" ] && [ ! -f "${pkgdir}/.stamp_cleanup" ] && [ ! -f "${pkgdir}/.stamp_configured" ]; then
        local patchtargets="${PAWPAW_TARGET}"
        if [[ "${PAWPAW_TARGET}" = "linux-"* ]]; then
            patchtargets+=" linux"
        elif [ "${PAWPAW_TARGET}" = "macos-universal-10.15" ]; then
            patchtargets+=" macos-10.15 macos-universal"
        elif [ "${PAWPAW_TARGET}" = "win64" ]; then
            patchtargets+=" win32"
        fi

        for target in ${patchtargets[@]}; do
            if [ -e "${PAWPAW_ROOT}/patches/${pkgname}/${target}" ]; then
                for p in $(ls "${PAWPAW_ROOT}/patches/${pkgname}/${target}/" | grep "\.patch$" | sort); do
                    if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                        patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${pkgname}/${target}/${p}"
                        touch "${pkgdir}/.stamp_applied_${p}"
                    fi
                done
            fi
        done

        for p in $(ls "${PAWPAW_ROOT}/patches/${pkgname}/" | grep "\.patch$" | sort); do
            if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${pkgname}/${p}"
                touch "${pkgdir}/.stamp_applied_${p}"
            fi
        done
    fi

    mkdir -p "${pkgdir}/build"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}/build"
        ${CMAKE_EXE_WRAPPER} ${cmake} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_INSTALL_PREFIX="${PAWPAW_PREFIX}-host" \
            -DCMAKE_MODULE_PATH="${PAWPAW_PREFIX}-host/lib/cmake" \
            -DBUILD_SHARED_LIBS=OFF \
            ${extraconfrules} ..
        touch ../.stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}/build"
        make ${MAKE_ARGS} ${EXTRA_MAKE_ARGS}
        touch ../.stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}/build"
        make ${MAKE_ARGS} -j 1 install
        touch ../.stamp_installed
        popd
    fi
}

# ---------------------------------------------------------------------------------------------------------------------

function patch_file() {
    local pkgname="${1}"
    local version="${2}"
    local file="${3}"
    local rule="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ -e "${pkgdir}/${file}" ]; then
        sed -i -e "${rule}" "${pkgdir}/${file}"
    fi
}

function copy_file() {
    local pkgname="${1}"
    local version="${2}"
    local source="${3}"
    local target="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ ! -e "${pkgdir}/${target}" ] || [ "${source}" -nt "${target}" ]; then
        pushd "${pkgdir}"
        cp -v "${source}" "${target}"
        popd
    fi
}

function install_file() {
    local pkgname="${1}"
    local version="${2}"
    local source="${3}"
    local targetdir="${4}"
    local targetname="${5}"

    if [ -z "${targetname}" ]; then
        targetname="$(basename ${source})"
    fi

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ ! -e "${PAWPAW_PREFIX}/${targetdir}/${targetname}" ]; then
        pushd "${pkgdir}"
        cp -v "${source}" "${PAWPAW_PREFIX}/${targetdir}/${targetname}"
        popd
    fi
}

function link_file() {
    local pkgname="${1}"
    local version="${2}"
    local source="${3}"
    local target="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ ! -e "${pkgdir}/${target}" ]; then
        pushd "${pkgdir}"
        ln -sfv "${source}" "${target}"
        popd
    fi
}

function link_host_file() {
    local pkgname="${1}"
    local version="${2}"
    local source="${3}"
    local target="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ ! -e "${PAWPAW_PREFIX}-host/${target}" ]; then
        ln -sfv "${source}" "${PAWPAW_PREFIX}-host/${target}"
    fi
}

function link_target_file() {
    local pkgname="${1}"
    local version="${2}"
    local source="${3}"
    local target="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ ! -e "${PAWPAW_PREFIX}/${target}" ]; then
        ln -sfv "${source}" "${PAWPAW_PREFIX}/${target}"
    fi
}

function remove_file() {
    local pkgname="${1}"
    local version="${2}"
    local file="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    if [ -e "${pkgdir}/${file}" ]; then
        rm -fv "${pkgdir}/${file}"
    fi
}

# ---------------------------------------------------------------------------------------------------------------------

function patch_osx_binary_libs() {
    local file="${1}"

    if [ -L "${file}" ]; then
        return 0
    fi

    idname=$(otool -D "${file}")

    if otool -L "${file}" | grep -v ":" | grep -v "${idname}" | grep -q "${PAWPAW_PREFIX}"; then
        #install_name_tool -change "@rpath/QtCore.framework/Versions/5/QtCore" "@executable_path/QtCore" "${file}"
        #install_name_tool -change "@rpath/QtGui.framework/Versions/5/QtGui" "@executable_path/QtGui" "${file}"
        #install_name_tool -change "@rpath/QtWidgets.framework/Versions/5/QtWidgets" "@executable_path/QtWidgets" "${file}"
        #install_name_tool -change "@rpath/QtXml.framework/Versions/5/QtXml" "@executable_path/QtXml" "${file}"
        install_name_tool -change "@executable_path/../Frameworks/libjack.0.dylib" "/usr/local/lib/libjack.0.dylib" "${file}"
        install_name_tool -change "${PAWPAW_PREFIX}/jack2/lib/libjack.0.dylib" "/usr/local/lib/libjack.0.dylib" "${file}"
        install_name_tool -change "${PAWPAW_PREFIX}/jack2/lib/libjacknet.0.dylib" "/usr/local/lib/libjacknet.0.dylib" "${file}"
        install_name_tool -change "${PAWPAW_PREFIX}/jack2/lib/libjackserver.0.dylib" "/usr/local/lib/libjackserver.0.dylib" "${file}"
     fi
}

function patch_osx_qtapp() {
    local pkgname="${1}"
    local version="${2}"
    local appfile="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}-${version}"

    _prebuild "${pkgname}" "${pkgdir}"

    mkdir -p "${appfile}/Contents/PlugIns/platforms"
    mkdir -p "${appfile}/Contents/PlugIns/printsupport"
    cp -v "${PAWPAW_PREFIX}/lib/qt5/plugins/platforms/libqcocoa.dylib" "${appfile}/Contents/PlugIns/platforms/"
    cp -v "${PAWPAW_PREFIX}/lib/qt5/plugins/printsupport/libcocoaprintersupport.dylib" "${appfile}/Contents/PlugIns/printsupport/"

    macdeployqt "${appfile}"

    rm -f "${appfile}/Contents/Frameworks/libjack.0.1.0.dylib"

    _postbuild
}

# ---------------------------------------------------------------------------------------------------------------------
