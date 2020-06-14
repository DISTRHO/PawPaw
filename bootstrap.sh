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

# TODO check for depedencies:
# - curl
# - cmake
# - make
# - jq
# - patch
# - python (waf, meson)
# - sed
# - tar

source setup/check_target.sh
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
build_autoconf liblo "${LIBLO_VERSION}" "--enable-threads --disable-examples --disable-tests --disable-tools"

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
# file/magic (posix only)

# if [ "${WIN32}" -eq 0 ]; then
#     download file "${FILE_VERSION}" "ftp://ftp.astron.com/pub/file"
#     build_autoconf file "${FILE_VERSION}"
# fi

# ---------------------------------------------------------------------------------------------------------------------
# libvorbis

download libvorbis "${LIBVORBIS_VERSION}" "https://ftp.osuosl.org/pub/xiph/releases/vorbis"
build_autoconf libvorbis "${LIBVORBIS_VERSION}" "--disable-examples"

# ---------------------------------------------------------------------------------------------------------------------
# flac

FLAC_EXTRAFLAGS="--disable-doxygen-docs --disable-examples --disable-thorough-tests"

if [ "${MACOS_OLD}" -eq 1 ]; then
    FLAC_EXTRAFLAGS="${FLAC_EXTRAFLAGS} --disable-asm-optimizations"
fi

download flac "${FLAC_VERSION}" "https://ftp.osuosl.org/pub/xiph/releases/flac" "tar.xz"
build_autoconf flac "${FLAC_VERSION}" "${FLAC_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# libsamplerate

download libsamplerate "${LIBSAMPLERATE_VERSION}" "http://www.mega-nerd.com/SRC"
build_autoconf libsamplerate "${LIBSAMPLERATE_VERSION}" "--disable-fftw --disable-sndfile"

# ---------------------------------------------------------------------------------------------------------------------
# libsndfile

download libsndfile "${LIBSNDFILE_VERSION}" "http://www.mega-nerd.com/libsndfile/files"
patch_file libsndfile "${LIBSNDFILE_VERSION}" "configure" 's/ -Wvla//'
build_autoconf libsndfile "${LIBSNDFILE_VERSION}" "--disable-full-suite --disable-alsa --disable-sqlite"

# ---------------------------------------------------------------------------------------------------------------------
# lv2

download lv2 "${LV2_VERSION}" "http://lv2plug.in/spec" "tar.bz2"
build_waf lv2 "${LV2_VERSION}" "--lv2dir=${PAWPAW_PREFIX}/lib/lv2 --no-coverage --no-plugins"

# ---------------------------------------------------------------------------------------------------------------------
# fftw

FFTW_EXTRAFLAGS="--enable-sse2 --disable-alloca --disable-fortran --with-our-malloc"

# if [ "${WIN32}" -eq 0 ]; then
#     FFTW_EXTRAFLAGS="${FFTW_EXTRAFLAGS} --enable-threads"
# fi

download fftw "${FFTW_VERSION}" "http://www.fftw.org"

if [ "${MACOS_OLD}" -eq 1 ]; then
    patch_file fftw "${FFTW_VERSION}" "configure" 's/CFLAGS="$CFLAGS -Wl,-no_compact_unwind"/CFLAGS="$CFLAGS"/'
    patch_file fftw "${FFTW_VERSION}" "libbench2/timer.c" 's/#if defined(HAVE_GETTIMEOFDAY) && !defined(HAVE_TIMER)/#ifndef HAVE_TIMER/'
fi

build_autoconf fftw "${FFTW_VERSION}" "${FFTW_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# fftwf

FFTWF_EXTRAFLAGS="${FFTW_EXTRAFLAGS} --enable-single"

copy_download fftw fftwf "${FFTW_VERSION}"

if [ "${MACOS_OLD}" -eq 1 ]; then
    patch_file fftwf "${FFTW_VERSION}" "configure" 's/CFLAGS="$CFLAGS -Wl,-no_compact_unwind"/CFLAGS="$CFLAGS"/'
    patch_file fftwf "${FFTW_VERSION}" "libbench2/timer.c" 's/#if defined(HAVE_GETTIMEOFDAY) && !defined(HAVE_TIMER)/#ifndef HAVE_TIMER/'
fi

build_autoconf fftwf "${FFTW_VERSION}" "${FFTWF_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
