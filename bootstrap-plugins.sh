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
# run bootstrap dependencies

./bootstrap-common.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# fftw

FFTW_EXTRAFLAGS="--disable-alloca --disable-fortran --with-our-malloc"

if [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
    FFTW_EXTRAFLAGS+=" --enable-sse2"
fi

# if [ "${WIN32}" -eq 0 ]; then
#     FFTW_EXTRAFLAGS+=" --enable-threads"
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
            patch_file glib ${GLIB_VERSION} "configure.in" 's/G_ATOMIC_I486/G_ATOMIC_NOT_I486/'
        fi
    elif [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ]; then
        patch_file glib ${GLIB_VERSION} "gobject/Makefile.in" "s|glib_genmarshal = ./glib-genmarshal|glib_genmarshal = ${EXE_WRAPPER} ./glib-genmarshal.exe|"
    fi

    build_autoconfgen glib ${GLIB_VERSION} "${GLIB_EXTRAFLAGS}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# liblo

download liblo "${LIBLO_VERSION}" "http://download.sourceforge.net/liblo"
build_autoconf liblo "${LIBLO_VERSION}" "--enable-threads --disable-examples --disable-tests --disable-tools"

# ---------------------------------------------------------------------------------------------------------------------
# pcre (needed for sord_validate, only relevant if we can run the resulting binaries)

if [ "${CROSS_COMPILING}" -eq 0 ] || [ -n "${EXE_WRAPPER}" ]; then
    download pcre "${PCRE_VERSION}" "https://ftp.pcre.org/pub/pcre"
    build_autoconf pcre "${PCRE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# lv2

download lv2 "${LV2_VERSION}" "http://lv2plug.in/spec" "tar.bz2"
build_waf lv2 "${LV2_VERSION}" "--lv2dir=${PAWPAW_PREFIX}/lib/lv2 --no-coverage --no-plugins"

# ---------------------------------------------------------------------------------------------------------------------
# serd

download serd "${SERD_VERSION}" "http://download.drobilla.net/" "tar.bz2"
build_waf serd "${SERD_VERSION}" "--static --no-shared --no-utils"

# ---------------------------------------------------------------------------------------------------------------------
# sord

if [ "${CROSS_COMPILING}" -eq 1 ] && [ -z "${EXE_WRAPPER}" ]; then
    SORD_EXTRAFLAGS="--no-utils"
fi

download sord "${SORD_VERSION}" "http://download.drobilla.net/" "tar.bz2"
build_waf sord "${SORD_VERSION}" "--static --no-shared ${SORD_EXTRAFLAGS}"

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

if [ "${LV2LINT_SUPPORTED}" -eq 1 ]; then
    download lv2lint "${LV2LINT_VERSION}" "https://gitlab.com/OpenMusicKontrollers/lv2lint/-/archive/${LV2LINT_VERSION}"
    build_meson lv2lint "${LV2LINT_VERSION}"
    # "-Donline-tests=true -Delf-tests=true"
fi

# ---------------------------------------------------------------------------------------------------------------------
# kxstudio lv2 extensions

download kxstudio-lv2-extensions "${KXSTUDIO_LV2_EXTENSIONS_VERSION}" "https://github.com/KXStudio/LV2-Extensions.git" "" "git"
build_make kxstudio-lv2-extensions "${KXSTUDIO_LV2_EXTENSIONS_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# MOD lv2 extensions

download mod-sdk "${MOD_SDK_VERSION}" "https://github.com/moddevices/mod-sdk.git" "" "git"
build_make mod-sdk "${MOD_SDK_VERSION}"

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

if [ "${MACOS}" -eq 1 ] && [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e" ]; then
    sed -i -e 's/-lfluidsynth/-lfluidsynth -lglib-2.0 -lgthread-2.0 -lsndfile -lFLAC -lvorbisenc -lvorbis -logg -lpthread -liconv -lm/' "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc"
fi

# ---------------------------------------------------------------------------------------------------------------------
# mxml

download mxml ${MXML_VERSION} "https://github.com/michaelrsweet/mxml/archive"
build_autoconf mxml ${MXML_VERSION}

# ---------------------------------------------------------------------------------------------------------------------
# zlib

if [ "${MACOS}" -eq 0 ]; then
    download zlib ${ZLIB_VERSION} "https://github.com/madler/zlib/archive"
    build_conf zlib ${ZLIB_VERSION} "--static --prefix=${PAWPAW_PREFIX}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# carla (backend only)

CARLA_EXTRAFLAGS="CAN_GENERATE_LV2_TTL=false"
CARLA_EXTRAFLAGS+=" HAVE_ALSA=false"
CARLA_EXTRAFLAGS+=" HAVE_JACK=false"
CARLA_EXTRAFLAGS+=" HAVE_PULSEAUDIO=false"
CARLA_EXTRAFLAGS+=" HAVE_DGL=false"
CARLA_EXTRAFLAGS+=" HAVE_HYLIA=false"
CARLA_EXTRAFLAGS+=" HAVE_GTK2=false"
CARLA_EXTRAFLAGS+=" HAVE_GTK3=false"
CARLA_EXTRAFLAGS+=" HAVE_X11=false"
CARLA_EXTRAFLAGS+=" HAVE_FFMPEG=false"
CARLA_EXTRAFLAGS+=" HAVE_FLUIDSYNTH=false"
CARLA_EXTRAFLAGS+=" HAVE_LIBLO=false"
CARLA_EXTRAFLAGS+=" HAVE_LIBMAGIC=false"
CARLA_EXTRAFLAGS+=" HAVE_PYQT=false"
CARLA_EXTRAFLAGS+=" HAVE_QT=false"
CARLA_EXTRAFLAGS+=" HAVE_QT4=false"
CARLA_EXTRAFLAGS+=" HAVE_QT5=false"
CARLA_EXTRAFLAGS+=" HAVE_SNDFILE=false"
CARLA_EXTRAFLAGS+=" EXTERNAL_PLUGINS=false"
CARLA_EXTRAFLAGS+=" USING_JUCE=false"
CARLA_EXTRAFLAGS+=" USING_JUCE_AUDIO_DEVICES=false"
CARLA_EXTRAFLAGS+=" USING_JUCE_GUI_EXTRA=false"

download carla ${CARLA_VERSION} "https://github.com/falkTX/Carla.git" "" "git"
build_make carla ${CARLA_VERSION} "${CARLA_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
