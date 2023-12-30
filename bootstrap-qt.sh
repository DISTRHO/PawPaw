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
# Use local Qt on Linux builds

if [ "${LINUX}" -eq 1 ]; then
    if [ "${LINUX_TARGET}" = "linux-aarch64" ]; then
        export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-armhf" ]; then
        export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-i686" ]; then
        export PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
        export PKG_CONFIG_PATH=/usr/lib/riscv64-linux-gnu/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-x86_64" ]; then
        export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
    fi
    if ! pkg-config --print-errors --exists Qt5Core Qt5Gui Qt5Svg Qt5Widgets; then
        echo "Qt system libs are not available, cannot continue"
        exit 2
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Core.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Core)/Qt5Core.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Core.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Gui.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Gui)/Qt5Gui.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Gui.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Svg.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Svg)/Qt5Svg.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Svg.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Widgets.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Widgets)/Qt5Widgets.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Widgets.pc
    fi
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------------------
# qt package suffix changes depending on the version

if [ "${QT5_MVERSION}" = "5.12" ]; then
    qtsuffix="-everywhere-src"
else
    qtsuffix="-opensource-src"
fi

# ---------------------------------------------------------------------------------------------------------------------
# custom functions for qt handling

function download_qt() {
    local name="${1}"

    local dlfile="${PAWPAW_DOWNLOADDIR}/${name}${qtsuffix}-${QT5_VERSION}.tar.xz"
    local dlfolder="${PAWPAW_BUILDDIR}/${name}${qtsuffix}-${QT5_VERSION}"

    if [ ! -f "${dlfile}" ]; then
        dlurl="${QT5_URL}/${name}${qtsuffix}-${QT5_VERSION}.tar.xz"
        curl -L "${dlurl}" -o "${dlfile}"
    fi

    if [ ! -d "${dlfolder}" ]; then
        mkdir "${dlfolder}"
        tar -xf "${dlfile}" -C "${dlfolder}" --strip-components=1
    fi
}

function build_qt_conf() {
    local pkgname="${1}"
    local extraconfrules="${2}"

    local pkgdir="${PAWPAW_BUILDDIR}/${pkgname}${qtsuffix}-${QT5_VERSION}"

    unset AR
    unset CC
    unset CXX
    unset LD
    unset STRIP
    unset CFLAGS
    unset CPPFLAGS
    unset CXXFLAGS
    unset LDFLAGS

    export PKG_CONFIG="${TARGET_PKG_CONFIG}"
    export PKG_CONFIG_LIBDIR="${TARGET_PKG_CONFIG_PATH}"
    export PKG_CONFIG_PATH="${TARGET_PKG_CONFIG_PATH}"
    export PKG_CONFIG_SYSROOT_DIR="/"

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
        make ${MAKE_ARGS} -j 1 install
        if [ "${WIN32}" -eq 1 ]; then
            sed -i -e "s|d ||" ${PAWPAW_PREFIX}/lib/pkgconfig/Qt5*.pc
        fi
        touch .stamp_installed
        popd
    fi

    unset PKG_CONFIG
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_PATH
    unset PKG_CONFIG_SYSROOT_DIR
}

# ---------------------------------------------------------------------------------------------------------------------
# qt config

# base
qtbase_conf_args="-opensource -confirm-license"
qtbase_conf_args+=" -c++std"
if [ "${QT5_MVERSION}" = "5.12" ]; then
    qtbase_conf_args+=" c++14"
else
    qtbase_conf_args+=" c++11"
fi
# qtbase_conf_args+=" -optimized-qmake"
qtbase_conf_args+=" -optimize-size"
qtbase_conf_args+=" -release -strip"
# qtbase_conf_args+=" -static"
qtbase_conf_args+=" -shared"
qtbase_conf_args+=" -silent"
# qtbase_conf_args+=" -verbose"

# build type
qtbase_conf_args+=" -make libs"
qtbase_conf_args+=" -make tools"
qtbase_conf_args+=" -gui"
qtbase_conf_args+=" -widgets"

# paths
qtbase_conf_args+=" -prefix ${PAWPAW_PREFIX}"
qtbase_conf_args+=" -headerdir ${PAWPAW_PREFIX}/include/qt5"
qtbase_conf_args+=" -libexecdir ${PAWPAW_PREFIX}/libexec"
qtbase_conf_args+=" -plugindir ${PAWPAW_PREFIX}/lib/qt5/plugins"

# enable optimizations (sse2 only)
if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    # TODO SSE2 and NEON
    qtbase_conf_args+=" -no-sse2"
else
    qtbase_conf_args+=" -sse2"
fi
qtbase_conf_args+=" -no-sse3 -no-ssse3 -no-sse4.1 -no-sse4.2 -no-avx -no-avx2 -no-avx512"

# enable some basic stuff
qtbase_conf_args+=" -opengl desktop"
qtbase_conf_args+=" -qt-doubleconversion"
qtbase_conf_args+=" -qt-freetype"
qtbase_conf_args+=" -qt-pcre"
qtbase_conf_args+=" -qt-sqlite"

# disable examples and tests
qtbase_conf_args+=" -nomake examples"
qtbase_conf_args+=" -nomake tests"
qtbase_conf_args+=" -no-compile-examples"

# disable a couple of things
qtbase_conf_args+=" -no-cups"
qtbase_conf_args+=" -no-dbus"
qtbase_conf_args+=" -no-directfb"
qtbase_conf_args+=" -no-eglfs"
qtbase_conf_args+=" -no-evdev"
qtbase_conf_args+=" -no-eventfd"
qtbase_conf_args+=" -no-journald"
qtbase_conf_args+=" -no-glib"
qtbase_conf_args+=" -no-gtk"
qtbase_conf_args+=" -no-icu"
qtbase_conf_args+=" -no-libinput"
qtbase_conf_args+=" -no-libproxy"
qtbase_conf_args+=" -no-mtdev"
qtbase_conf_args+=" -no-openssl"
qtbase_conf_args+=" -no-pch"
qtbase_conf_args+=" -no-sctp"
qtbase_conf_args+=" -no-securetransport"
qtbase_conf_args+=" -no-syslog"
qtbase_conf_args+=" -no-tslib"

if [ "${LINUX}" -eq 0 ]; then
    qtbase_conf_args+=" -no-fontconfig"
    qtbase_conf_args+=" -no-inotify"
    qtbase_conf_args+=" -no-linuxfb"
fi

if [ "${QT5_MVERSION}" = "5.9" ]; then
    qtbase_conf_args+=" -no-xinput2"
    qtbase_conf_args+=" -no-xkbcommon-evdev"
    qtbase_conf_args+=" -no-xkbcommon-x11"
fi

if [ "${QT5_MVERSION}" = "5.12" ]; then
    qtbase_conf_args+=" -qt-harfbuzz"
else
    qtbase_conf_args+=" -no-harfbuzz"
fi

# supported image formats
qtbase_conf_args+=" -qt-libjpeg"
qtbase_conf_args+=" -qt-libpng"
qtbase_conf_args+=" -no-gif"
qtbase_conf_args+=" -no-ico"

# use pkg-config
qtbase_conf_args+=" -pkg-config"
qtbase_conf_args+=" -force-pkg-config"

# platform specific
if [ -n "${TOOLCHAIN_PREFIX}" ]; then
    if [ "${LINUX}" -eq 1 ]; then
        if [ "${LINUX_TARGET}" = "linux-aarch64" ]; then
            qtbase_conf_args+=" -xplatform linux-aarch64-gnu-g++"
        elif [ "${LINUX_TARGET}" = "linux-armhf" ]; then
            qtbase_conf_args+=" -xplatform linux-arm-gnueabi-g++"
        elif [ "${LINUX_TARGET}" = "linux-i686" ]; then
            qtbase_conf_args+=" -xplatform linux-g++-32"
        elif [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
            echo "error unsupported qt config"
            exit 3
            # qtbase_conf_args+=" -xplatform linux-g++"
        elif [ "${LINUX_TARGET}" = "linux-x86_64" ]; then
            qtbase_conf_args+=" -xplatform linux-g++-64"
        else
            qtbase_conf_args+=" -xplatform linux-g++"
        fi
    elif [ "${MACOS}" -eq 1 ]; then
        qtbase_conf_args+=" -xplatform macx-clang"
    elif [ "${WIN32}" -eq 1 ]; then
        qtbase_conf_args+=" -xplatform win32-g++"
    fi
    qtbase_conf_args+=" -device-option CROSS_COMPILE=${TOOLCHAIN_PREFIX_}"
else
    if [ "${LINUX}" -eq 1 ]; then
        qtbase_conf_args+=" -platform linux-g++"
    elif [ "${MACOS}" -eq 1 ]; then
        qtbase_conf_args+=" -platform macx-clang"
    elif [ "${WIN32}" -eq 1 ]; then
        qtbase_conf_args+=" -platform win32-g++"
    fi
fi

# platform specific
if [ "${LINUX}" -eq 1 ]; then
    qtbase_conf_args+=" -qpa xcb"
    qtbase_conf_args+=" -qt-xcb"
    #qtbase_conf_args+=" -xcb-xlib"
    #qtbase_conf_args+=" -xcb-xinput"
elif [ "${MACOS}" -eq 1 ]; then
    qtbase_conf_args+=" -qpa cocoa"
elif [ "${WIN32}" -eq 1 ]; then
    qtbase_conf_args+=" -qpa windows"
fi

# zlib
if [ "${MACOS}" -eq 1 ]; then
    qtbase_conf_args+=" -system-zlib"
else
    qtbase_conf_args+=" -qt-zlib"
fi

# ---------------------------------------------------------------------------------------------------------------------
# qt build

download_qt qtbase

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/common/macx.conf" 's/QMAKE_APPLE_DEVICE_ARCHS = x86_64/QMAKE_APPLE_DEVICE_ARCHS = arm64 x86_64/'
    patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/common/macx.conf" 's/QT_MAC_SDK_VERSION_MIN = 10.13/QT_MAC_SDK_VERSION_MIN = 10.12/'
    patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/common/macx.conf" 's/QT_MAC_SDK_VERSION_MAX = 10.15/QT_MAC_SDK_VERSION_MAX = 10.12/'
    patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/features/toolchain.prf" 's/-arch $$QMAKE_APPLE_DEVICE_ARCHS/-arch arm64/'
elif [ "${MACOS_10_15}" -eq 1 ]; then
    patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/common/macx.conf" 's/QT_MAC_SDK_VERSION_MIN = 10.13/QT_MAC_SDK_VERSION_MIN = 10.15/'
elif [ "${MACOS}" -eq 1 ]; then
    patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/macx-clang/qmake.conf" 's/10.10/10.8/'
elif [ "${WIN32}" -eq 1 ]; then
    if [ "${QT5_MVERSION}" = "5.12" ]; then
        patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/common/g++-win32.conf" 's/= -shared/= -static -shared/'
        patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/win32-g++/qmake.conf" 's/= -fno-keep-inline-dllexport/= -Wno-deprecated-copy -Wno-deprecated-declarations -fno-keep-inline-dllexport/'
    else
        patch_file qtbase${qtsuffix} ${QT5_VERSION} "mkspecs/win32-g++/qmake.conf" 's/= -shared/= -static -shared/'
        patch_file qtbase${qtsuffix} ${QT5_VERSION} "src/plugins/platforms/direct2d/direct2d.pro" 's/-lVersion/-lversion/'
    fi
fi

build_qt_conf qtbase "${qtbase_conf_args}"

if [ "${MACOS}" -eq 1 ] && [ ! -e "${PAWPAW_PREFIX}/include/qt5/QtWidgets" ]; then
    ln -sfv ${PAWPAW_PREFIX}/lib/QtCore.framework/Headers ${PAWPAW_PREFIX}/include/qt5/QtCore
    ln -sfv ${PAWPAW_PREFIX}/lib/QtGui.framework/Headers ${PAWPAW_PREFIX}/include/qt5/QtGui
    ln -sfv ${PAWPAW_PREFIX}/lib/QtWidgets.framework/Headers ${PAWPAW_PREFIX}/include/qt5/QtWidgets
fi

# ---------------------------------------------------------------------------------------------------------------------
# qtmacextras

if [ "${MACOS}" -eq 1 ]; then
    download_qt qtmacextras
    build_qmake qtmacextras${qtsuffix} ${QT5_VERSION}
fi

# ---------------------------------------------------------------------------------------------------------------------
# qtsvg

download_qt qtsvg
build_qmake qtsvg${qtsuffix} ${QT5_VERSION}

# ---------------------------------------------------------------------------------------------------------------------
# qttools (host only, thus not needed if cross-compiling)

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    if [ "${QT5_MVERSION}" = "5.12" ]; then
        QTTOOLS_EXTRAFLAGS=". -- -no-feature-qdoc"
    fi
    download_qt qttools
    build_qmake qttools${qtsuffix} ${QT5_VERSION} "${QTTOOLS_EXTRAFLAGS}"
fi

# ---------------------------------------------------------------------------------------------------------------------
