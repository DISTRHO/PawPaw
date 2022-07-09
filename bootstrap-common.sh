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
# let's use some native libs for linux builds

if [ "${LINUX}" -eq 1 ]; then
    mkdir -p ${TARGET_PKG_CONFIG_PATH}
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/dbus-1.pc" ]; then
        cp $(pkg-config --variable=pcfiledir dbus-1)/dbus-1.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/dbus-1.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/gl.pc" ]; then
        cp $(pkg-config --variable=pcfiledir gl)/gl.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/gl.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/glib-2.0.pc" ]; then
        cp $(pkg-config --variable=pcfiledir glib-2.0)/g{io,lib,module,object,thread}-2.0.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/g{io,lib,module,object,thread}-2.0.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/libpcre.pc" ]; then
        cp $(pkg-config --variable=pcfiledir libpcre)/libpcre.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/libpcre.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/pthread-stubs.pc" ]; then
        cp $(pkg-config --variable=pcfiledir pthread-stubs)/pthread-stubs.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/pthread-stubs.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/x11.pc" ]; then
        cp $(pkg-config --variable=pcfiledir x11)/x11.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/x11.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xcb.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xcb)/{xau,xcb,xdmcp}.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/{xau,xcb,xdmcp}.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xcursor.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xcursor)/xcursor.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xcursor.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xext.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xext)/xext.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xext.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xfixes.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xfixes)/xfixes.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xfixes.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xproto.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xproto)/{fixesproto,kbproto,randrproto,renderproto,xextproto,xproto}.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/{fixesproto,kbproto,randrproto,renderproto,xextproto,xproto}.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xrandr.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xrandr)/xrandr.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xrandr.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xrender.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xrender)/xrender.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xrender.pc
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

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make libogg "${LIBOGG_VERSION}" "check -j 1"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libvorbis

LIBVORBIS_EXTRAFLAGS="--disable-examples"

download libvorbis "${LIBVORBIS_VERSION}" "${LIBVORBIS_URL}"
build_autoconf libvorbis "${LIBVORBIS_VERSION}" "${LIBVORBIS_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make libvorbis "${LIBVORBIS_VERSION}" "check -j 1"
fi

# ---------------------------------------------------------------------------------------------------------------------
# flac

FLAC_EXTRAFLAGS="--disable-doxygen-docs --disable-examples --disable-thorough-tests --disable-xmms-plugin"

# force intrinsic optimizations on macos-universal target
if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    FLAC_EXTRAFLAGS+=" ac_cv_header_x86intrin_h=yes asm_opt=yes"
fi

download flac "${FLAC_VERSION}" "${FLAC_URL}" "tar.xz"

# fixup for intrinsic optimizations on macos-universal target
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

# FIXME macos-universal proper optimizations
if [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-intrinsics"
fi

if [ -n "${PAWPAW_SKIP_FORTIFY}" ] && [ "${PAWPAW_SKIP_FORTIFY}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-stack-protector"
fi

download opus "${OPUS_VERSION}" "${OPUS_URL}"
build_autoconf opus "${OPUS_VERSION}" "${OPUS_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make opus "${OPUS_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# libsndfile

LIBSNDFILE_EXTRAFLAGS="--disable-alsa --disable-full-suite --disable-sqlite"

# force disable mp3 support for now, until we handle those libs
LIBSNDFILE_EXTRAFLAGS+=" --disable-mpeg"

# force intrinsic optimizations on macos-universal target
if [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
    LIBSNDFILE_EXTRAFLAGS+=" ac_cv_header_immintrin_h=yes"
fi

# fix build, regex matching fails
if [ "${WASM}" -eq 1 ]; then
    LIBSNDFILE_EXTRAFLAGS+=" ax_cv_c_compiler_version=15.0.0"
    LIBSNDFILE_EXTRAFLAGS+=" ax_cv_cxx_compiler_version=15.0.0"
fi

# otherwise tests fail
export EXTRA_CFLAGS="-fno-associative-math -frounding-math"

if [ "${MACOS}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
    export EXTRA_CFLAGS+=" -fno-reciprocal-math"
else
    export EXTRA_CFLAGS+=" -fsignaling-nans"
fi

download libsndfile "${LIBSNDFILE_VERSION}" "${LIBSNDFILE_URL}" "tar.xz"

build_autoconf libsndfile "${LIBSNDFILE_VERSION}" "${LIBSNDFILE_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make libsndfile "${LIBSNDFILE_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# libsamplerate

if [ -z "${PAWPAW_SKIP_SAMPLERATE}" ]; then

LIBSAMPLERATE_EXTRAFLAGS="--disable-fftw"

# NOTE: sndfile tests use Carbon, which is not always available on macOS
if [ "${CROSS_COMPILING}" -eq 1 ] || [ "${MACOS}" -eq 1 ]; then
    LIBSAMPLERATE_EXTRAFLAGS+=" --disable-sndfile"
fi

download libsamplerate "${LIBSAMPLERATE_VERSION}" "${LIBSAMPLERATE_URL}"
build_autoconf libsamplerate "${LIBSAMPLERATE_VERSION}" "${LIBSAMPLERATE_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${MACOS}" -eq 0 ]; then
    run_make libsamplerate "${LIBSAMPLERATE_VERSION}" check
fi

fi # PAWPAW_SKIP_SAMPLERATE

# ---------------------------------------------------------------------------------------------------------------------
# zlib (skipped on macOS)

if [ "${MACOS}" -eq 0 ]; then
    git_clone zlib "${ZLIB_VERSION}" "${ZLIB_URL}"
    build_conf zlib "${ZLIB_VERSION}" "--static --prefix=${PAWPAW_PREFIX}"

    if [ "${CROSS_COMPILING}" -eq 0 ]; then
        run_make zlib "${ZLIB_VERSION}" check
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
