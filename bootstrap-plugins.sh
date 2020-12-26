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

./bootstrap-common.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# fftw

FFTW_EXTRAFLAGS="--disable-alloca --disable-fortran --with-our-malloc"

if [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
    FFTW_EXTRAFLAGS="${FFTW_EXTRAFLAGS} --enable-sse2"
fi

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

        if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
            patch_file glib ${GLIB_VERSION} "glib/gatomic.c" 's/G_ATOMIC_ARM/__aarch64__/'
            patch_file glib ${GLIB_VERSION} "glib/gatomic.c" 's/G_ATOMIC_X86_64/__SSE2__/'
        elif [ "${MACOS_OLD}" -eq 1 ]; then
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
# lv2

download lv2 "${LV2_VERSION}" "http://lv2plug.in/spec" "tar.bz2"
build_waf lv2 "${LV2_VERSION}" "--lv2dir=${PAWPAW_PREFIX}/lib/lv2 --no-coverage --no-plugins"

# ---------------------------------------------------------------------------------------------------------------------
# serd

download serd "${SERD_VERSION}" "http://download.drobilla.net/" "tar.bz2"
build_waf serd "${SERD_VERSION}" "--static --no-shared"

# ---------------------------------------------------------------------------------------------------------------------
# sord

download sord "${SORD_VERSION}" "http://download.drobilla.net/" "tar.bz2"
build_waf sord "${SORD_VERSION}" "--static --no-shared --no-utils"

# ---------------------------------------------------------------------------------------------------------------------
# sratom

download sratom "${SRATOM_VERSION}" "http://download.drobilla.net/" "tar.bz2"
build_waf sratom "${SRATOM_VERSION}" "--static --no-shared"

# ---------------------------------------------------------------------------------------------------------------------
# lilv

download lilv "${LILV_VERSION}" "http://download.drobilla.net/" "tar.bz2"
build_waf lilv "${LILV_VERSION}" "--static --no-bash-completion --no-bindings --no-shared"
# --static-progs

# ---------------------------------------------------------------------------------------------------------------------
# lv2lint

if [ "${MACOS_OLD}" -eq 0 ] && [ "${CROSS_COMPILING}" -eq 0 ]; then
    download lv2lint "${LV2LINT_VERSION}" "https://gitlab.com/OpenMusicKontrollers/lv2lint/-/archive/${LV2LINT_VERSION}"
    build_meson lv2lint "${LV2LINT_VERSION}"
    # "-Donline-tests=true -Delf-tests=true"
fi

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
