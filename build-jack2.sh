#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

JACK2_VERSION=${JACK2_VERSION:=git}
JACK_ROUTER_VERSION=${JACK_ROUTER_VERSION:=6c2e532bb05d2ba59ef210bef2fe270d588c2fdf}
QJACKCTL_VERSION=${QJACKCTL_VERSION:=0.9.7}

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

# TODO check that bootstrap-jack.sh has been run

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------

jack2_repo="https://github.com/jackaudio/jack2.git"

if [ -n "${PAWPAW_JACK2_NO_CUSTOM_PREFIX}" ]; then
    jack2_prefix="${PAWPAW_PREFIX}"
else
    jack2_prefix="${PAWPAW_PREFIX}-jack2"

    if [ "${MACOS}" -eq 1 ]; then
        jack2_extra_prefix="/usr/local"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# jack2

jack2_args=""

if [ -n "${jack2_extra_prefix}" ]; then
    jack2_args+=" --prefix=${jack2_extra_prefix}"
    jack2_args+=" --destdir="${jack2_prefix}""
else
    jack2_args+=" --prefix=${jack2_prefix}"
fi

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${LINUX}" -eq 1 ]; then
        jack2_args+=" --platform=linux"
    elif [ "${MACOS}" -eq 1 ]; then
        jack2_args+=" --platform=darwin"
    elif [ "${WIN32}" -eq 1 ]; then
        jack2_args+=" --platform=win32"
    fi
fi

if [ "${WIN32}" -eq 1 ]; then
    jack2_args+=" --static"
fi

if [ "${WIN64}" -eq 1 ]; then
    jack2_args="${jack2_args} --mixed"
    # win32 toolchain prefix
    TOOLCHAIN_PREFIX32=$(echo ${TOOLCHAIN_PREFIX} | sed 's/x86_64/i686/')
    # let jack2 find win32 binaries
    TARGET_PATH="${TARGET_PATH}:/usr/${TOOLCHAIN_PREFIX32}/bin"
    # setup linker for our custom folder
    export EXTRA_LDFLAGS="-L${PAWPAW_PREFIX}/lib32"
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
rm -f "${jack2_prefix}${jack2_extra_prefix}/bin/jack_control"

# generate MSVC lib files
if [ "${WIN64}" -eq 1 ]; then
    llvm-dlltool -m i386 -D libjack.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib32/libjack.def -l ${jack2_prefix}${jack2_extra_prefix}/lib32/libjack.lib
    llvm-dlltool -m i386:x86-64 -D libjack64.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib/libjack64.def -l ${jack2_prefix}${jack2_extra_prefix}/lib/libjack64.lib
    llvm-dlltool -m i386:x86-64 -D libjacknet64.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib/libjacknet64.def -l ${jack2_prefix}${jack2_extra_prefix}/lib/libjacknet64.lib
    llvm-dlltool -m i386:x86-64 -D libjackserver64.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib/libjackserver64.def -l ${jack2_prefix}${jack2_extra_prefix}/lib/libjackserver64.lib
elif [ "${WIN32}" -eq 1 ]; then
    llvm-dlltool -m i386 -D libjack.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib/libjack.def -l ${jack2_prefix}${jack2_extra_prefix}/lib/libjack.lib
    llvm-dlltool -m i386 -D libjacknet.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib/libjacknet.def -l ${jack2_prefix}${jack2_extra_prefix}/lib/libjacknet.lib
    llvm-dlltool -m i386 -D libjackserver.dll -d ${jack2_prefix}${jack2_extra_prefix}/lib/libjackserver.def -l ${jack2_prefix}${jack2_extra_prefix}/lib/libjackserver.lib
fi

# copy jack pkg-config file to main system, so qjackctl can find it
if [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc" ]; then
    cp -v "${jack2_prefix}${jack2_extra_prefix}/lib/pkgconfig/jack.pc" "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc"

    # patch pkg-config file for static win32 builds in regular prefix
    if [ "${WIN32}" -eq 1 ]; then
        if [ "${WIN64}" -eq 1 ]; then
            s="64"
        else
            s=""
        fi
        sed -i -e "s/lib -ljack${s}/lib -Wl,-Bdynamic -ljack${s} -Wl,-Bstatic/" "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# jack-router (download, win32 only)

if [ "${WIN32}" -eq 1 ]; then
    download jack-router "${JACK_ROUTER_VERSION}" "https://github.com/jackaudio/jack-router.git" "" "git"
fi

# ---------------------------------------------------------------------------------------------------------------------
# qjackctl (if qt is available)

if [ -f "${PAWPAW_PREFIX}/bin/moc" ]; then
    # Join $2+ arguments into a string separated by $1
    function join() {
        local IFS=$1
        shift
        echo "$*"
    }

    if [ "${CROSS_COMPILING}" -eq 1 ]; then
        # Use system's Qt tools for translations
        qjackctl_CMAKE_PREFIX_PATH="${PAWPAW_PREFIX}/lib/cmake;$(join ';' /usr/{lib/$(gcc -print-multiarch),lib*,share}/cmake)"
        echo "Using CMake prefix: ${qjackctl_CMAKE_PREFIX_PATH}"
    else
        qjackctl_CMAKE_PREFIX_PATH="${PAWPAW_PREFIX}/lib/cmake"
    fi

    QJACKCTL_EXTRAFLAGS="-DJack_ROOT=${jack2_prefix}${jack2_extra_prefix}"
    QJACKCTL_EXTRAFLAGS+=" -DCONFIG_ALSA_SEQ:BOOL=OFF"
    QJACKCTL_EXTRAFLAGS+=" -DCONFIG_DBUS:BOOL=OFF"
    QJACKCTL_EXTRAFLAGS+=" -DCMAKE_PREFIX_PATH=${qjackctl_CMAKE_PREFIX_PATH}"
    QJACKCTL_EXTRAFLAGS+=" -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON"

    download qjackctl "${QJACKCTL_VERSION}" https://download.sourceforge.net/qjackctl
    build_cmake qjackctl "${QJACKCTL_VERSION}" "${QJACKCTL_EXTRAFLAGS}"

    if [ "${WIN32}" -eq 1 ]; then
        copy_file qjackctl "${QJACKCTL_VERSION}" "build/src/qjackctl.exe" "${jack2_prefix}/bin/qjackctl.exe"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
