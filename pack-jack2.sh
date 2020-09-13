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

if [ ! -e jack2 ]; then
    ln -s "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}" jack2
fi

# ---------------------------------------------------------------------------------------------------------------------

if [ "${WIN32}" -eq 1 ]; then
    dlfile="${PAWPAW_DOWNLOADDIR}/innosetup-6.0.5.exe"
    innodir="${PAWPAW_BUILDDIR}/innosetup-6.0.5"
    iscc="${innodir}/drive_c/InnoSeup/ISCC.exe"
    wine="env WINEARCH="${PAWPAW_TARGET}" WINEDLLOVERRIDES="mscoree,mshtml=" WINEPREFIX="${innodir}" wine"

    if [ ! -f "${dlfile}" ]; then
        # FIXME proper dl version
        curl -L https://jrsoftware.org/download.php/is.exe?site=2 -o "${dlfile}"
    fi

    if [ ! -d "${innodir}"/drive_c ]; then
        ${wine}boot -u
    fi

    if [ ! -f "${innodir}"/drive_c/InnoSeup/ISCC.exe ]; then
        ${wine} "${dlfile}" /allusers /dir=C:\\InnoSeup /nocancel /norestart /verysilent
    fi

    pushd "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}/windows/inno"
    echo "#define VERSION \"${JACK2_VERSION}\"" > "version.iss"
    ln -sf "${PAWPAW_PREFIX}/bin/Qt5"{Core,Gui,Network,Widgets,Xml}".dll" .
    ln -sf "${PAWPAW_PREFIX}/lib/qt5/plugins/platforms/qwindows.dll" .
    ln -sf "${jack2_prefix}" "${PAWPAW_TARGET}"
    ${wine} "${iscc}" "${PAWPAW_TARGET}.iss"
    popd

    mv "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}/windows/inno/"*.exe .

elif [ "${MACOS}" -eq 1 ]; then
    for f in $(ls "${jack2_prefix}${jack2_extra_prefix}/bin"/* \
                  "${jack2_prefix}${jack2_extra_prefix}/lib"/*.dylib \
                  "${jack2_prefix}${jack2_extra_prefix}/lib/jack"/*); do
        patch_osx_binary_libs "${f}"
    done

    jack2_lastversion=$(cat jack2/wscript | awk 'sub("VERSION=","")' | tr -d "'")
    ./jack2/macosx/generate-pkg.sh "${jack2_prefix}${jack2_extra_prefix}/"

    qjackctl_app="${PAWPAW_PREFIX}/bin/qjackctl.app"
    qjackctl_dir="${qjackctl_app}/Contents/MacOS"
    patch_osx_qtapp qjackctl "${QJACKCTL_VERSION}" "${qjackctl_app}"
    patch_osx_binary_libs "${qjackctl_dir}/qjackctl"

    rm -rf jack2/macosx/qjackctl.app
    cp -rv "${PAWPAW_PREFIX}/bin/qjackctl.app" jack2/macosx/

    rm -f jack2-macOS-${JACK2_VERSION}.tar.gz
    tar czf jack2-macOS-${JACK2_VERSION}.tar.gz -C jack2/macosx jack2-osx-${jack2_lastversion}.pkg qjackctl.app
fi

# ---------------------------------------------------------------------------------------------------------------------
