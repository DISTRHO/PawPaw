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
                if [ x"${dlmethod}" = x"nv" ]; then
                    dlurl="${dlbaseurl}/${version}.${dlext}"
                else
                    dlurl="${dlbaseurl}/v${version}.${dlext}"
                fi
            elif [ "${dlext}" = "orig.tar.gz" ]; then
                dlurl="${dlbaseurl}/${name}_${version}.${dlext}"
            else
                dlurl="${dlbaseurl}/${name}-${version}.${dlext}"
            fi
            curl -L "${dlurl}" -o "${dlfile}" --fail
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
    export CFLAGS="${TARGET_CFLAGS} ${EXTRA_CFLAGS}"
    export CXXFLAGS="${TARGET_CXXFLAGS} ${EXTRA_CXXFLAGS}"
    export LDFLAGS="${TARGET_LDFLAGS} ${EXTRA_LDFLAGS}"
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

    if [ -d "${PAWPAW_ROOT}/patches/${name}/${PAWPAW_TARGET}" ]; then
        for p in $(ls "${PAWPAW_ROOT}/patches/${name}/${PAWPAW_TARGET}/" | grep "\.patch" | sort); do
            if [ ! -f "${pkgdir}/.stamp_applied_${p}" ]; then
                patch -p1 -d "${pkgdir}" -i "${PAWPAW_ROOT}/patches/${name}/${PAWPAW_TARGET}/${p}"
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
    unset LD
    unset STRIP
    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS
    unset PKG_CONFIG_PATH

    unset EXTRA_CFLAGS
    unset EXTRA_CXXFLAGS
    unset EXTRA_LDFLAGS
    unset EXTRA_MAKE_ARGS

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
        ./configure --enable-static --disable-shared --disable-debug --disable-doc --disable-docs --disable-maintainer-mode --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
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
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    local EXTRA_CFLAGS2="${EXTRA_CFLAGS}"
    local EXTRA_CXXFLAGS2="${EXTRA_CXXFLAGS}"
    local EXTRA_LDFLAGS2="${EXTRA_LDFLAGS}"
    local EXTRA_MAKE_ARGS2="${EXTRA_MAKE_ARGS}"

    _prebuild "${name}" "${pkgdir}"

    if [ ! -f "${pkgdir}/.stamp_preconfigured" ]; then
        pushd "${pkgdir}"
        autoconf
        touch .stamp_preconfigured
        popd
    fi

    _postbuild

    export EXTRA_CFLAGS="${EXTRA_CFLAGS2}"
    export EXTRA_CXXFLAGS="${EXTRA_CXXFLAGS2}"
    export EXTRA_LDFLAGS="${EXTRA_LDFLAGS2}"
    export EXTRA_MAKE_ARGS="${EXTRA_MAKE_ARGS2}"

    build_autoconf "${name}" "${version}" "${extraconfrules}"
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
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules+=" -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}"
    fi
    if [ "${MACOS}" -eq 1 ]; then
        if [ "${MACOS_OLD}" -eq 1 ]; then
            OSX_TARGET="10.5"
        elif [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
            OSX_TARGET="10.12"
        else
            OSX_TARGET="10.8"
        fi
        extraconfrules+=" -DCMAKE_OSX_DEPLOYMENT_TARGET=${OSX_TARGET}"
    fi

    _prebuild "${name}" "${pkgdir}"
    mkdir -p "${pkgdir}/build"

    if [ ! -f "${pkgdir}/.stamp_configured" ]; then
        pushd "${pkgdir}/build"
        cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_PREFIX="${PAWPAW_PREFIX}" ${extraconfrules} ..
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
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

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
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        extraconfrules="--cross-file "${PAWPAW_ROOT}/setup/meson/${PAWPAW_TARGET}.ini" ${extraconfrules}"
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

function build_python() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"
    local python=python3

    if [ ! -e "${PAWPAW_PREFIX}/bin/python3" ] && ! which python3 > /dev/null; then
        python=python
    fi

    _prebuild "${name}" "${pkgdir}"

    # fix build of python packages
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-ffast-math//')"
    export CFLAGS="$(echo ${CFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility=hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-ffast-math//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fvisibility-inlines-hidden//')"
    export CXXFLAGS="$(echo ${CXXFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-Wl,-dead_strip -Wl,-dead_strip_dylibs//')"
    export LDFLAGS="$(echo ${LDFLAGS} | sed -e 's/-fdata-sections -ffunction-sections//')"

    touch "${pkgdir}/.stamp_configured"

    if [ ! -f "${pkgdir}/.stamp_built" ]; then
        pushd "${pkgdir}"
        ${python} setup.py build ${extraconfrules}
        touch .stamp_built
        popd
    fi

    if [ ! -f "${pkgdir}/.stamp_installed" ]; then
        pushd "${pkgdir}"
        ${python} setup.py install --prefix="${PAWPAW_PREFIX}" ${extraconfrules}
        touch .stamp_installed
        popd
    fi

    _postbuild
}

function build_qmake() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

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

    _postbuild
}

function build_waf() {
    local name="${1}"
    local version="${2}"
    local extraconfrules="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"
    local python=python3

    if ! which python3 > /dev/null; then
        python=python
    fi

    _prebuild "${name}" "${pkgdir}"

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
        make ${MAKE_ARGS} install -j 1
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

    if [ -e "${pkgdir}/${file}" ]; then
        sed -i -e "${rule}" "${pkgdir}/${file}"
    fi
}

function copy_file() {
    local name="${1}"
    local version="${2}"
    local source="${3}"
    local target="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ ! -e "${pkgdir}/${target}" ] || [ "${source}" -nt "${target}" ]; then
        pushd "${pkgdir}"
        cp -v "${source}" "${target}"
        popd
    fi
}

function install_file() {
    local name="${1}"
    local version="${2}"
    local source="${3}"
    local targetdir="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ ! -e "${PAWPAW_PREFIX}/${targetdir}/$(basename ${source})" ]; then
        pushd "${pkgdir}"
        cp -v "${source}" "${PAWPAW_PREFIX}/${targetdir}/"
        popd
    fi
}

function link_file() {
    local name="${1}"
    local version="${2}"
    local source="${3}"
    local target="${4}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    if [ ! -e "${pkgdir}/${target}" ]; then
        pushd "${pkgdir}"
        ln -sfv "${source}" "${target}"
        popd
    fi
}

function remove_file() {
    local name="${1}"
    local version="${2}"
    local file="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

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
    local name="${1}"
    local version="${2}"
    local appfile="${3}"

    local pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"

    _prebuild "${name}" "${pkgdir}"

    mkdir -p "${appfile}/Contents/PlugIns/platforms"
    mkdir -p "${appfile}/Contents/PlugIns/printsupport"
    cp -v "${PAWPAW_PREFIX}/lib/qt5/plugins/platforms/libqcocoa.dylib" "${appfile}/Contents/PlugIns/platforms/"
    cp -v "${PAWPAW_PREFIX}/lib/qt5/plugins/printsupport/libcocoaprintersupport.dylib" "${appfile}/Contents/PlugIns/printsupport/"

    macdeployqt "${appfile}"

    rm -f "${appfile}/Contents/Frameworks/libjack.0.dylib"

    _postbuild
}

# ---------------------------------------------------------------------------------------------------------------------
