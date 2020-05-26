#!/bin/bash

set -e

cd $(dirname ${0})

# ---------------------------------------------------------------------------------------------------------------------

# TODO CLI args

# NOTE all of these need to be defined. either 0 or 1
CROSS_COMPILING=1
MACOS=0
MACOS_OLD=0
WIN32=1
WIN64=1

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
# now the fun: plugins!

for p in $(ls plugins); do
    name=$(jq -crM .name plugins/${p})
    version=$(jq -crM .version plugins/${p})
    buildtype=$(jq -crM .buildtype plugins/${p})
    dlbaseurl=$(jq -crM .dlbaseurl plugins/${p})

    # optional args
    buildargs=$(echo -e $(jq -ecrM .buildargs plugins/${p} || echo '\n\n') | tail -n 1)
    dlext=$(echo -e $(jq -ecrM .dlext plugins/${p} || echo '\n\n') | tail -n 1)
    dlmethod=$(echo -e $(jq -ecrM .dlmethod plugins/${p} || echo '\n\n') | tail -n 1)

    download "${name}" "${version}" "${dlbaseurl}" "${dlext}" "${dlmethod}"

    # TODO patch_file support?

    case ${buildtype} in
        "autoconf")
            build_autoconf "${name}" "${version}" "${buildargs}"
            ;;
        "conf")
            build_conf "${name}" "${version}" "${buildargs}"
            ;;
        "cmake")
            build_cmake "${name}" "${version}" "${buildargs}"
            ;;
        "make")
            build_make "${name}" "${version}" "${buildargs}"
            ;;
        "meson")
            build_meson "${name}" "${version}" "${buildargs}"
            ;;
        "waf")
            build_waf "${name}" "${version}" "${buildargs}"
            ;;
    esac
done

# ---------------------------------------------------------------------------------------------------------------------
