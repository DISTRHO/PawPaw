#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

JACK2_VERSION=${JACK2_VERSION:=git}
JACK_ROUTER_VERSION=${JACK_ROUTER_VERSION:=6c2e532bb05d2ba59ef210bef2fe270d588c2fdf}
QJACKCTL_VERSION=${QJACKCTL_VERSION:=0.9.5}

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

if [ ! -e jack2 ]; then
    ln -s "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}" jack2
fi

# ---------------------------------------------------------------------------------------------------------------------

if [ "${WIN32}" -eq 1 ]; then
    # setup innosetup
    dlfile="${PAWPAW_DOWNLOADDIR}/innosetup-6.0.5.exe"
    innodir="${PAWPAW_BUILDDIR}/innosetup-6.0.5"
    iscc="${innodir}/drive_c/InnoSetup/ISCC.exe"

    # download it
    if [ ! -f "${dlfile}" ]; then
        # FIXME proper dl version
        curl -L https://jrsoftware.org/download.php/is.exe?site=2 -o "${dlfile}"
    fi

    # initialize wine
    if [ ! -d "${innodir}"/drive_c ]; then
        env WINEPREFIX="${innodir}" wineboot -u
    fi

    # install innosetup in custom wineprefix
    if [ ! -f "${innodir}"/drive_c/InnoSetup/ISCC.exe ]; then
        env WINEPREFIX="${innodir}" wine "${dlfile}" /allusers /dir=C:\\InnoSetup /nocancel /norestart /verysilent
    fi

    # copy jackrouter binaries
    mkdir -p "${jack2_prefix}/jack-router/win32"
    mkdir -p "${jack2_prefix}/jack-router/win64"
    copy_file jack-router "${JACK_ROUTER_VERSION}" "README-win" "${jack2_prefix}/jack-router/README.txt"
    copy_file jack-router "${JACK_ROUTER_VERSION}" "binaries/win32/JackRouter.dll" "${jack2_prefix}/jack-router/win32/JackRouter.dll"
    copy_file jack-router "${JACK_ROUTER_VERSION}" "binaries/win32/JackRouter.ini" "${jack2_prefix}/jack-router/win32/JackRouter.ini"
    if [ "${WIN64}" -eq 1 ]; then
        copy_file jack-router "${JACK_ROUTER_VERSION}" "binaries/win64/JackRouter.dll" "${jack2_prefix}/jack-router/win64/JackRouter.dll"
        copy_file jack-router "${JACK_ROUTER_VERSION}" "binaries/win64/JackRouter.ini" "${jack2_prefix}/jack-router/win64/JackRouter.ini"
    fi

    # finally create the installer file
    pushd "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}/windows/inno"
    echo "#define VERSION \"${JACK2_VERSION}\"" > "version.iss"
    ln -sf "${PAWPAW_PREFIX}/bin/Qt5"{Core,Gui,Network,Widgets,Xml}".dll" .
    ln -sf "${PAWPAW_PREFIX}/lib/qt5/plugins/platforms/qwindows.dll" .
    ln -sf "${PAWPAW_PREFIX}/lib/qt5/plugins/styles/qwindowsvistastyle.dll" .
    ln -sf "${jack2_prefix}" "${PAWPAW_TARGET}"
    env WINEPREFIX="${innodir}" wine "${iscc}" "${PAWPAW_TARGET}.iss"
    popd

    # and move installer file where CI expects it to be
    mv "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}/windows/inno/"*.exe .

elif [ "${MACOS}" -eq 1 ]; then
    for f in $(ls "${jack2_prefix}${jack2_extra_prefix}/bin"/* \
                  "${jack2_prefix}${jack2_extra_prefix}/lib"/*.dylib \
                  "${jack2_prefix}${jack2_extra_prefix}/lib/jack"/*); do
        patch_osx_binary_libs "${f}"
    done

    jack2_lastversion=$(cat jack2/wscript | awk 'sub("VERSION = ","")' | head -n 1 | tr -d "'")
    ./jack2/macosx/generate-pkg.sh "${jack2_prefix}${jack2_extra_prefix}/"

    qjackctl_app="${PAWPAW_PREFIX}/bin/QjackCtl.app"
    qjackctl_dir="${qjackctl_app}/Contents/MacOS"
    patch_osx_qtapp qjackctl "${QJACKCTL_VERSION}" "${qjackctl_app}"
    patch_osx_binary_libs "${qjackctl_dir}/QjackCtl"

    rm -rf jack2/macosx/QjackCtl.app
    cp -rv "${qjackctl_app}" jack2/macosx/QjackCtl.app

    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        variant="universal"
    else
        variant="intel"
    fi

    rm -f jack2-macOS-${variant}-${JACK2_VERSION}.tar.gz
    tar czf jack2-macOS-${variant}-${JACK2_VERSION}.tar.gz -C jack2/macosx jack2-osx-${jack2_lastversion}.pkg QjackCtl.app
fi

# ---------------------------------------------------------------------------------------------------------------------
