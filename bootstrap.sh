#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target>"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------

CROSS_COMPILING=0
MACOS=0
MACOS_OLD=0
WIN32=0
WIN64=0

case ${target} in
    "macos")
        MACOS=1
        ;;
    "macos-old")
        MACOS=1
        MACOS_OLD=1
        CROSS_COMPILING=1
        ;;
    "win32")
        WIN32=1
        CROSS_COMPILING=1
        ;;
    "win64")
        WIN32=1
        WIN64=1
        CROSS_COMPILING=1
        ;;
    "native")
        echo "TODO"
        exit 2
        ;;
    default)
        echo "Invalid target '${target}', possible values are:"
        echo "\tmacos"
        echo "\tmacos-old"
        echo "\twin32"
        echo "\twin64"
        echo "\tnative"
        exit 2
        ;;
esac

# ---------------------------------------------------------------------------------------------------------------------

# TODO check for depedencies:
# - curl
# - cmake
# - make
# - jq
# - python (waf, meson)
# - sed
# - tar

source setup/env.sh
source setup/functions.sh
source setup/versions.sh

mkdir -p ${PAWPAW_BUILDDIR}
mkdir -p ${PAWPAW_DOWNLOADDIR}
mkdir -p ${PAWPAW_PREFIX}
mkdir -p ${PAWPAW_TMPDIR}

# ---------------------------------------------------------------------------------------------------------------------
# pkgconfig

download pkg-config "${PKG_CONFIG_VERSION}" "https://pkg-config.freedesktop.org/releases"
build_host_autoconf pkg-config "${PKG_CONFIG_VERSION}" "--enable-indirect-deps --with-internal-glib --with-pc-path=${TARGET_PKG_CONFIG_PATH}"

# ---------------------------------------------------------------------------------------------------------------------
# liblo

download liblo "${LIBLO_VERSION}" "http://download.sourceforge.net/liblo"
build_autoconf liblo "${LIBLO_VERSION}" "--enable-threads --disable-examples --disable-tools"

# ---------------------------------------------------------------------------------------------------------------------
# zlib

download zlib "${ZLIB_VERSION}" "https://github.com/madler/zlib/archive"
build_conf zlib "${ZLIB_VERSION}" "--static --prefix=${PAWPAW_PREFIX}"

# ---------------------------------------------------------------------------------------------------------------------
# libogg

download libogg "${LIBOGG_VERSION}" "https://ftp.osuosl.org/pub/xiph/releases/ogg"
patch_file libogg "${LIBOGG_VERSION}" "include/ogg/os_types.h" 's/__MACH__/__MACH_SKIP__/'
build_autoconf libogg "${LIBOGG_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# file/magic

# download file "${FILE_VERSION}" "ftp://ftp.astron.com/pub/file"
# build_autoconf file "${FILE_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# libvorbis

download libvorbis "${LIBVORBIS_VERSION}" "https://ftp.osuosl.org/pub/xiph/releases/vorbis"
build_autoconf libvorbis "${LIBVORBIS_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# flac

download flac "${FLAC_VERSION}" "https://ftp.osuosl.org/pub/xiph/releases/flac" "tar.xz"
build_autoconf flac "${FLAC_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# libsndfile

download libsndfile "${LIBSNDFILE_VERSION}" "http://www.mega-nerd.com/libsndfile/files"
patch_file libsndfile "${LIBSNDFILE_VERSION}" "configure" 's/ -Wvla//'
build_autoconf libsndfile "${LIBSNDFILE_VERSION}" "--disable-full-suite --disable-alsa --disable-sqlite"

# ---------------------------------------------------------------------------------------------------------------------
# lv2

download lv2 "${LV2_VERSION}" "http://lv2plug.in/spec" "tar.bz2"
build_waf lv2 "${LV2_VERSION}" "--lv2dir=${PAWPAW_PREFIX}/lib/lv2"

# ---------------------------------------------------------------------------------------------------------------------
# fftw

download fftw "${FFTW_VERSION}" "http://www.fftw.org"
build_autoconf fftw "${FFTW_VERSION}" "--enable-sse2 --disable-debug --disable-alloca --disable-fortran --with-our-malloc"

# ---------------------------------------------------------------------------------------------------------------------
# fftwf

copy_download fftw fftwf "${FFTW_VERSION}" 
build_autoconf fftwf "${FFTW_VERSION}" "--enable-single --enable-sse2 --disable-debug --disable-alloca --disable-fortran --with-our-malloc"

# ---------------------------------------------------------------------------------------------------------------------
