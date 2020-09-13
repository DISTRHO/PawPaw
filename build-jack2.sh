#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

JACK2_VERSION=${JACK2_VERSION:=git}
QJACKCTL_VERSION=${QJACKCTL_VERSION:=0.6.2}

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target> [package-build?]"
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
jack2_prefix="${PAWPAW_PREFIX}-jack2"

if [ "${MACOS}" -eq 1 ]; then
    jack2_extra_prefix="/usr/local"
fi

# ---------------------------------------------------------------------------------------------------------------------
# jack2

jack2_args="--prefix=${jack2_prefix}"
# if [ "${MACOS_OLD}" -eq 1 ] || [ "${WIN64}" -eq 1 ]; then
#     jack2_args="${jack2_args} --mixed"
# fi
if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${LINUX}" -eq 1 ]; then
        jack2_args+=" --platform=linux"
    elif [ "${MACOS}" -eq 1 ]; then
        jack2_args+=" --platform=darwin"
    elif [ "${WIN32}" -eq 1 ]; then
        jack2_args+=" --platform=win32"
    fi
fi
if [ "${MACOS}" -eq 1 ]; then
    jack2_args+=" --prefix=${jack2_extra_prefix}"
    jack2_args+=" --destdir="${jack2_prefix}""
elif [ "${WIN32}" -eq 1 ]; then
    jack2_args+=" --static"
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
        # FIXME rule that works for server lib too, maybe ignoring suffix even
        sed -i -e "s/lib -ljack${s}/lib -Wl,-Bdynamic -ljack${s} -Wl,-Bstatic/" "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# qjackctl (if qt is available)

if [ -f "${PAWPAW_PREFIX}/bin/moc" ]; then
    download qjackctl ${QJACKCTL_VERSION} https://download.sourceforge.net/qjackctl

    if [ "${WIN64}" -eq 1 ]; then
        patch_file qjackctl "${QJACKCTL_VERSION}" "configure" 's/-ljack /-Wl,-Bdynamic -ljack64 -Wl,-Bstatic /'
    elif [ "${WIN32}" -eq 1 ]; then
        patch_file qjackctl "${QJACKCTL_VERSION}" "configure" 's/-ljack /-Wl,-Bdynamic -ljack -Wl,-Bstatic /'
    fi

    if [ "${MACOS}" -eq 1 ]; then
        qjackctl_extra_args="--with-jack="${jack2_prefix}${jack2_extra_prefix}""
    elif [ "${WIN32}" -eq 1 ]; then
        qjackctl_extra_args="--enable-portaudio"
    fi

    build_autoconf qjackctl "${QJACKCTL_VERSION}" "--enable-jack-version ${qjackctl_extra_args}"

    if [ "${WIN32}" -eq 1 ]; then
        copy_file qjackctl "${QJACKCTL_VERSION}" "src/release/qjackctl.exe" "${jack2_prefix}/bin/qjackctl.exe"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
