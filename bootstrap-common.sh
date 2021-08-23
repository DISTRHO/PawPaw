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

# TODO check for depedencies:
# - curl
# - cmake
# - make
# - jq
# - patch
# - python (waf, meson)
# - sed
# - tar

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# create common directories

mkdir -p "${PAWPAW_BUILDDIR}"
mkdir -p "${PAWPAW_DOWNLOADDIR}"
mkdir -p "${PAWPAW_PREFIX}"
mkdir -p "${PAWPAW_TMPDIR}"

# ---------------------------------------------------------------------------------------------------------------------
# let's use native glib for linux builds

if [ "${LINUX}" -eq 1 ]; then
    mkdir -p ${TARGET_PKG_CONFIG_PATH}
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/glib-2.0.pc" ]; then
        ln -s $(pkg-config --variable=pcfiledir glib-2.0)/g{io,lib,module,object,thread}-2.0.pc ${TARGET_PKG_CONFIG_PATH}/
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/libpcre.pc" ]; then
        ln -s $(pkg-config --variable=pcfiledir libpcre)/libpcre.pc ${TARGET_PKG_CONFIG_PATH}/
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# pkgconfig

download pkg-config "${PKG_CONFIG_VERSION}" "${PKG_CONFIG_URL}"
build_host_autoconf pkg-config "${PKG_CONFIG_VERSION}" "--enable-indirect-deps --with-internal-glib --with-pc-path=${TARGET_PKG_CONFIG_PATH}"

if [ "${CROSS_COMPILING}" -eq 1 ] && [ ! -e "${PAWPAW_PREFIX}/bin/${TOOLCHAIN_PREFIX_}pkg-config" ]; then
    ln -s pkg-config "${PAWPAW_PREFIX}/bin/${TOOLCHAIN_PREFIX_}pkg-config"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libogg

download libogg "${LIBOGG_VERSION}" "${LIBOGG_URL}"
build_autoconf libogg "${LIBOGG_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# libvorbis

LIBVORBIS_EXTRAFLAGS="--disable-examples"

download libvorbis "${LIBVORBIS_VERSION}" "${LIBVORBIS_URL}"
build_autoconf libvorbis "${LIBVORBIS_VERSION}" "${LIBVORBIS_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# flac (forces intrinsic optimizations on macos-universal target)

FLAC_EXTRAFLAGS="--disable-doxygen-docs --disable-examples --disable-thorough-tests --disable-xmms-plugin"

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    FLAC_EXTRAFLAGS+=" ac_cv_header_x86intrin_h=yes asm_opt=yes"
fi

download flac "${FLAC_VERSION}" "${FLAC_URL}" "tar.xz"

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    patch_file flac "${FLAC_VERSION}" "configure" 's/amd64|x86_64/amd64|arm|x86_64/'
fi

build_autoconf flac "${FLAC_VERSION}" "${FLAC_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make flac "${FLAC_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# opus

OPUS_EXTRAFLAGS="--enable-custom-modes --enable-float-approx"

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-extra-programs"
fi
if [ "${MACOS_OLD}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-intrinsics"
fi

# FIXME macos-universal proper optimizations
if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-intrinsics"
fi

download opus "${OPUS_VERSION}" "${OPUS_URL}"
build_autoconf opus "${OPUS_VERSION}" "${OPUS_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make opus "${OPUS_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# libsndfile

LIBSNDFILE_EXTRAFLAGS="--disable-alsa --disable-full-suite --disable-sqlite"

# otherwise tests fail
export EXTRA_CFLAGS="-frounding-math -fsignaling-nans"

if [ "${MACOS_OLD}" -eq 0 ]; then
    export EXTRA_CFLAGS+=" -fno-associative-math"
fi

download libsndfile "${LIBSNDFILE_VERSION}" "${LIBSNDFILE_URL}" "tar.bz2"

if [ "${MACOS_OLD}" -eq 1 ]; then
    patch_file libsndfile "${LIBSNDFILE_VERSION}" "src/sfconfig.h" 's/#define USE_SSE2/#undef USE_SSE2/'
fi

build_autoconf libsndfile "${LIBSNDFILE_VERSION}" "${LIBSNDFILE_EXTRAFLAGS}"

# FIXME tests fail on macos-universal
if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
    run_make libsndfile "${LIBSNDFILE_VERSION}" "check -j 8"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libsamplerate

LIBSAMPLERATE_EXTRAFLAGS="--disable-fftw"

# NOTE: sndfile tests use Carbon, not available on macos-universal
if [ "${CROSS_COMPILING}" -eq 1 ] || [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    LIBSAMPLERATE_EXTRAFLAGS+=" --disable-sndfile"
fi

download libsamplerate "${LIBSAMPLERATE_VERSION}" "${LIBSAMPLERATE_URL}"
build_autoconf libsamplerate "${LIBSAMPLERATE_VERSION}" "${LIBSAMPLERATE_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
    run_make libsamplerate "${LIBSAMPLERATE_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# zlib (skipped on macOS)

if [ "${MACOS}" -eq 0 ]; then
    git_clone zlib "${ZLIB_VERSION}" "https://github.com/madler/zlib.git"
    build_conf zlib "${ZLIB_VERSION}" "--static --prefix=${PAWPAW_PREFIX}"
fi

# ---------------------------------------------------------------------------------------------------------------------
