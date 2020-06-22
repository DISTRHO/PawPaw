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

mkdir -p "${PAWPAW_BUILDDIR}"
mkdir -p "${PAWPAW_DOWNLOADDIR}"
mkdir -p "${PAWPAW_PREFIX}"
mkdir -p "${PAWPAW_TMPDIR}"

# ---------------------------------------------------------------------------------------------------------------------
# let's use native glib for linux builds

if [ "${LINUX}" -eq 1 ] && [ ! -e "${TARGET_PKG_CONFIG_PATH}/glib-2.0.pc" ]; then
    mkdir -p ${TARGET_PKG_CONFIG_PATH}
    ln -s $(pkg-config --variable=pcfiledir glib-2.0)/g{io,lib,module,object,thread}-2.0.pc ${TARGET_PKG_CONFIG_PATH}/
    ln -s $(pkg-config --variable=pcfiledir libpcre)/libpcre.pc ${TARGET_PKG_CONFIG_PATH}/
fi

# ---------------------------------------------------------------------------------------------------------------------
# pkgconfig

download pkg-config "${PKG_CONFIG_VERSION}" "https://pkg-config.freedesktop.org/releases"
build_host_autoconf pkg-config "${PKG_CONFIG_VERSION}" "--enable-indirect-deps --with-internal-glib --with-pc-path=${TARGET_PKG_CONFIG_PATH}"

# ---------------------------------------------------------------------------------------------------------------------
# file/magic (posix only)

# if [ "${WIN32}" -eq 0 ]; then
#     download file "${FILE_VERSION}" "ftp://ftp.astron.com/pub/file"
#     build_autoconf file "${FILE_VERSION}"
# fi

# ---------------------------------------------------------------------------------------------------------------------
# glib

if [ "${MACOS}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    if [ "${WIN32}" -eq 1 ]; then
        GLIB_EXTRAFLAGS="--with-threads=win32"
    else
        GLIB_EXTRAFLAGS="--with-threads=posix"
    fi

    download glib ${GLIB_VERSION} "http://caesar.ftp.acc.umu.se/pub/GNOME/sources/glib/${GLIB_MVERSION}" "${GLIB_TAR_EXT}"

    if [ "${MACOS}" -eq 1 ]; then
        export EXTRA_LDFLAGS="-lresolv"
        patch_file glib ${GLIB_VERSION} "glib/gconvert.c" '/#error/g'

        if [ "${MACOS_OLD}" -eq 1 ]; then
            GLIB_EXTRAFLAGS+=" glib_cv_stack_grows=yes"
            GLIB_EXTRAFLAGS+=" glib_cv_rtldglobal_broken=no"
            GLIB_EXTRAFLAGS+=" glib_cv_uscore=no"
            GLIB_EXTRAFLAGS+=" ac_cv_func_posix_getpwuid_r=yes"
            GLIB_EXTRAFLAGS+=" ac_cv_func_posix_getgrgid_r=yes"
            patch_file glib ${GLIB_VERSION} "configure.in" 's/G_ATOMIC_I486/G_ATOMIC_I486_NOT/'
        fi
    fi

    build_autoconfgen glib ${GLIB_VERSION} "${GLIB_EXTRAFLAGS}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# liblo

download liblo "${LIBLO_VERSION}" "http://download.sourceforge.net/liblo"
build_autoconf liblo "${LIBLO_VERSION}" "--enable-threads --disable-examples --disable-tests --disable-tools"

# ---------------------------------------------------------------------------------------------------------------------
# libogg

download libogg "${LIBOGG_VERSION}" "https://ftp.osuosl.org/pub/xiph/releases/ogg"
patch_file libogg "${LIBOGG_VERSION}" "include/ogg/os_types.h" 's/__MACH__/__MACH_SKIP__/'
build_autoconf libogg "${LIBOGG_VERSION}"

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
# fluidsynth

FLUIDSYNTH_EXTRAFLAGS="-Denable-floats=ON"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-alsa=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-aufile=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-coreaudio=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-coremidi=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-dbus=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-debug=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-fpe-check=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-framework=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-ipv6=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-jack=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-ladcca=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-ladspa=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-lash=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-midishare=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-oss=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-portaudio=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-profiling=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-pulseaudio=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-readline=OFF"
FLUIDSYNTH_EXTRAFLAGS+=" -Denable-trap-on-fpe=OFF"

download fluidsynth ${FLUIDSYNTH_VERSION} "https://github.com/FluidSynth/fluidsynth/archive"
patch_file fluidsynth ${FLUIDSYNTH_VERSION} "CMakeLists.txt" 's/_init_lib_suffix "64"/_init_lib_suffix ""/'
build_cmake fluidsynth ${FLUIDSYNTH_VERSION} "${FLUIDSYNTH_EXTRAFLAGS}"
# touch src/fluidsynth

# sed -i -e "s|-lfluidsynth|-lfluidsynth -lglib-2.0 -lgthread-2.0 -lsndfile -lFLAC -lvorbisenc -lvorbis -logg -lpthread -lm -liconv|" ${PREFIX}/lib/pkgconfig/fluidsynth.pc

# ---------------------------------------------------------------------------------------------------------------------
# mxml

download mxml ${MXML_VERSION} "https://github.com/michaelrsweet/mxml/archive"
build_autoconf mxml ${MXML_VERSION} "--disable-shared --prefix=${PAWPAW_PREFIX}"

# ---------------------------------------------------------------------------------------------------------------------
# zlib

if [ "${MACOS}" -eq 0 ]; then
    download zlib ${ZLIB_VERSION} "https://github.com/madler/zlib/archive"
    build_conf zlib ${ZLIB_VERSION} "--static --prefix=${PAWPAW_PREFIX}"
fi

# ---------------------------------------------------------------------------------------------------------------------
