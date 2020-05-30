#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------

function download() {
    local name="${1}"
    local version="${2}"
    local dlbaseurl="${3}"
    local dlext="${4}"
    local dlmethod="${5}"

    if [ -z "${dlext}" ]; then
        dlext="tar.gz"
    fi

    local dlfile="${PAWPAW_DOWNLOADDIR}/${name}-${version}.${dlext}"
    local dlfolder="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ ! -f "${dlfile}" ]; then
        if [ -n "${dlmethod}" ] && [ "${dlmethod}" = "git" ]; then
            local tmprepodir="${PAWPAW_TMPDIR}/${name}-${version}"
            rm -rf "${tmprepodir}"
            git clone --recursive "${dlbaseurl}" "${tmprepodir}"
            git -C "${tmprepodir}" checkout "${version}"
            git -C "${tmprepodir}" submodule update
            tar --exclude=".git" -czf "${dlfile}" -C "${PAWPAW_TMPDIR}" "${name}-${version}"
            rm -rf "${tmprepodir}"
        else
            local dlurl
            if echo ${dlbaseurl} | grep -q github.com; then
                dlurl="${dlbaseurl}/v${version}.${dlext}"
            else
                dlurl="${dlbaseurl}/${name}-${version}.${dlext}"
            fi
            curl -L "${dlurl}" -o "${dlfile}"
        fi
    fi

    if [ ! -d "${dlfolder}" ]; then
        mkdir "${dlfolder}"
        tar -xf "${dlfile}" -C "${dlfolder}" --strip-components=1
    fi
}

function copy_download() {
    local name1="${1}"
    local name2="${2}"
    local version="${3}"
    local dlext="${4}"

    if [ -z "${dlext}" ]; then
        dlext="tar.gz"
    fi

    local dlfile1="${PAWPAW_DOWNLOADDIR}/${name1}-${version}.${dlext}"
    local dlfolder2="${PAWPAW_BUILDDIR}/${name2}-${version}"

    if [ ! -d "${dlfolder2}" ]; then
        mkdir "${dlfolder2}"
        tar -xf "${dlfile1}" -C "${dlfolder2}" --strip-components=1
    fi
}

# ---------------------------------------------------------------------------------------------------------------------

function _prebuild() {
    local name="${1}"
    local pkgdir="${2}"

    export AR="${TARGET_AR}"
    export CC="${TARGET_CC}"
    export CXX="${TARGET_CXX}"
    export LD="${TARGET_LD}"
    export STRIP="${TARGET_STRIP}"
    export CFLAGS="${TARGET_CFLAGS}"
    export CXXFLAGS="${TARGET_CXXFLAGS}"
    export LDFLAGS="${TARGET_LDFLAGS}"
    export PKG_CONFIG="${TARGET_PKG_CONFIG}"
    export PKG_CONFIG_PATH="${TARGET_PKG_CONFIG_PATH}"

    unset CPPFLAGS
    export OLD_PATH="${PATH}"
    export PATH="${TARGET_PATH}"

    if [ -d "${PAWPAW_ROOT}/patches/${name}" ]; then
        for p in $(ls "${PAWPAW_ROOT}/patches/${name}/" | grep "\.patch" | sort); do
            if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${name}/${p}"
                touch "${pkgdir}/.stamp_applied_${p}"
            fi
        done
    fi

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        rm -f "${pkgdir}/.stamp_built"
        rm -f "${pkgdir}/.stamp_installed"

    elif [ ! -f "${pkgdir}/.stamp_built" ]; then
        rm -f "${pkgdir}/.stamp_installed"

    fi
}

function _postbuild() {
    unset AR
    unset CC
    unset CXX
    unset LD
    unset STRIP
    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset PKG_CONFIG
    unset PKG_CONFIG_PATH

    export PATH="${OLD_PATH}"
}

# ---------------------------------------------------------------------------------------------------------------------

function build_autoconf() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules="--host=${TOOLCHAIN_PREFIX} ${extraconfrules}"
    fi

    _prebuild "${name}" "${pkgdir}"

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
        make ${MAKE_ARGS} install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_conf() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./configure ${extraconfrules}
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
        make ${MAKE_ARGS} install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_cmake() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules="-DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME} ${extraconfrules}"
    fi

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        # FIXME put this as a patch file
        sed -i -e 's/ -Wl,--no-undefined//' CMakeLists.txt
        cmake -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_PREFIX="${PAWPAW_PREFIX}" ${extraconfrules}
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
        make ${MAKE_ARGS} install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_make() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

    touch "${pkgdir}/.stamp_configured"

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" ${MAKE_ARGS} ${extraconfrules}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        make PREFIX="${PAWPAW_PREFIX}" ${MAKE_ARGS} install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_meson() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules="--cross-file ${PAWPAW_ROOT}/setup/meson/${PAWPAW_TARGET}.ini ${extraconfrules}"
    fi

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        meson build --buildtype release --prefix "${PAWPAW_PREFIX}" ${extraconfrules}
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        ninja -v -C build
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        ninja -C build install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_waf() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}"
        ./waf configure --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
        touch .stamp_configured
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        ./waf build
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        ./waf install
        touch .stamp_installed
        popd
    fi

    _postbuild
}

# ---------------------------------------------------------------------------------------------------------------------

function build_host_autoconf() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    unset AR
    unset CC
    unset CXX
    unset LD
    unset STRIP
    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS

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
        make install
        touch .stamp_installed
        popd
    fi
}

# ---------------------------------------------------------------------------------------------------------------------

function patch_file() {
    local name="${1}"
    local version="${2}"
    local file="${3}"
    local rule="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    sed -i -e "${rule}" "${pkgdir}/${file}"
}

# ---------------------------------------------------------------------------------------------------------------------
