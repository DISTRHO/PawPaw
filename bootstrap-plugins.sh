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

# FIXME macos-universal proper optimizations
if [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
    FFTW_EXTRAFLAGS+=" --enable-sse2"
fi

# if [ "${WIN32}" -eq 0 ]; then
#     FFTW_EXTRAFLAGS+=" --enable-threads"
# fi

download fftw "${FFTW_VERSION}" "${FFTW_URL}"
build_autoconf fftw "${FFTW_VERSION}" "${FFTW_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make fftw "${FFTW_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# fftwf

FFTWF_EXTRAFLAGS="${FFTW_EXTRAFLAGS} --enable-single"

copy_download fftw fftwf "${FFTW_VERSION}"
build_autoconf fftwf "${FFTW_VERSION}" "${FFTWF_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make fftwf "${FFTW_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# pcre

if [ "${MACOS}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    download pcre "${PCRE_VERSION}" "${PCRE_URL}"
    build_autoconf pcre "${PCRE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libffi

if [ "${WIN32}" -eq 1 ]; then
    download libffi "${LIBFFI_VERSION}" "${LIBFFI_URL}"
    build_autoconf libffi "${LIBFFI_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# glib

if [ "${MACOS}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    GLIB_EXTRAFLAGS="--disable-rebuilds"

    if [ "${WIN32}" -eq 1 ]; then
        GLIB_EXTRAFLAGS+=" --with-threads=win32"
    else
        GLIB_EXTRAFLAGS+=" --with-threads=posix"
    fi

    if [ "${WIN64}" -eq 1 ]; then
        export EXTRA_CFLAGS="-Wno-format"
    fi

    download glib ${GLIB_VERSION} "${GLIB_URL}" "tar.xz"
    build_autoconfgen glib ${GLIB_VERSION} "${GLIB_EXTRAFLAGS}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# liblo

LIBLO_EXTRAFLAGS="--enable-threads --disable-examples --disable-tools"

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    LIBLO_EXTRAFLAGS+=" --disable-tests"
fi

# auto-detection fails
if [ "${MACOS}" -eq 1 ]; then
    LIBLO_EXTRAFLAGS+=" ac_cv_func_select=yes ac_cv_func_poll=yes ac_cv_func_setvbuf=yes"
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        LIBLO_EXTRAFLAGS+=" ac_cv_c_bigendian=universal"
    fi
fi

download liblo "${LIBLO_VERSION}" "${LIBLO_URL}"
build_autoconf liblo "${LIBLO_VERSION}" "${LIBLO_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make liblo "${LIBLO_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# lv2

git_clone lv2 "${LV2_VERSION}" "${LV2_URL}"
build_waf lv2 "${LV2_VERSION}" "--lv2dir=${PAWPAW_PREFIX}/lib/lv2 --no-coverage --no-plugins"

# ---------------------------------------------------------------------------------------------------------------------
# serd

download serd "${SERD_VERSION}" "${SERD_URL}" "tar.bz2"
build_waf serd "${SERD_VERSION}" "--static --no-shared --no-utils"

# ---------------------------------------------------------------------------------------------------------------------
# sord

if [ "${CROSS_COMPILING}" -eq 1 ] && [ -z "${EXE_WRAPPER}" ]; then
    SORD_EXTRAFLAGS="--no-utils"
fi

download sord "${SORD_VERSION}" "${SORD_URL}" "tar.bz2"
build_waf sord "${SORD_VERSION}" "--static --no-shared ${SORD_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# sratom

download sratom "${SRATOM_VERSION}" "${SRATOM_URL}" "tar.bz2"
build_waf sratom "${SRATOM_VERSION}" "--static --no-shared"

# ---------------------------------------------------------------------------------------------------------------------
# lilv

download lilv "${LILV_VERSION}" "${LILV_URL}" "tar.bz2"
build_waf lilv "${LILV_VERSION}" "--static --no-bash-completion --no-bindings --no-shared"
# --static-progs

# ---------------------------------------------------------------------------------------------------------------------
# lv2lint

if [ "${LV2LINT_SUPPORTED}" -eq 1 ]; then
    download lv2lint "${LV2LINT_VERSION}" "${LV2LINT_URL}"
    build_meson lv2lint "${LV2LINT_VERSION}"
    # "-Donline-tests=true -Delf-tests=true"
fi

# ---------------------------------------------------------------------------------------------------------------------
# kxstudio lv2 extensions

git_clone kxstudio-lv2-extensions "${KXSTUDIO_LV2_EXTENSIONS_VERSION}" "${KXSTUDIO_LV2_EXTENSIONS_URL}"
build_make kxstudio-lv2-extensions "${KXSTUDIO_LV2_EXTENSIONS_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# MOD lv2 extensions

git_clone mod-sdk "${MOD_SDK_VERSION}" "${MOD_SDK_URL}"
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

git_clone fluidsynth "${FLUIDSYNTH_VERSION}" "${FLUIDSYNTH_URL}"
patch_file fluidsynth "${FLUIDSYNTH_VERSION}" "CMakeLists.txt" 's/_init_lib_suffix "64"/_init_lib_suffix ""/'
build_cmake fluidsynth "${FLUIDSYNTH_VERSION}" "${FLUIDSYNTH_EXTRAFLAGS}"

if [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e" ]; then
    FLUIDSYNTH_EXTRALIBS="-lglib-2.0 -lgthread-2.0 -lsndfile -lFLAC -lvorbisenc -lvorbis -lopus -logg -lpthread -lm"
    if [ "${MACOS}" -eq 1 ]; then
        FLUIDSYNTH_EXTRALIBS+=" -liconv"
    elif [ "${WIN32}" -eq 1 ]; then
        FLUIDSYNTH_EXTRALIBS+=" -lole32 -lws2_32"
    fi
    sed -i -e "s/-L${libdir} -lfluidsynth/-L${libdir}  -lfluidsynth ${FLUIDSYNTH_EXTRALIBS}/" "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc"
    touch "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e"
fi

# ---------------------------------------------------------------------------------------------------------------------
# mxml

git_clone mxml "${MXML_VERSION}" "${MXML_URL}"
build_autoconf mxml "${MXML_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# carla (backend only)

CARLA_EXTRAFLAGS="CAN_GENERATE_LV2_TTL=false"
CARLA_EXTRAFLAGS+=" EXTERNAL_PLUGINS=false"
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
CARLA_EXTRAFLAGS+=" NOOPT=true"
CARLA_EXTRAFLAGS+=" USING_JUCE=false"
CARLA_EXTRAFLAGS+=" USING_JUCE_AUDIO_DEVICES=false"
CARLA_EXTRAFLAGS+=" USING_JUCE_GUI_EXTRA=false"

git_clone carla "${CARLA_VERSION}" "${CARLA_URL}"
build_make carla "${CARLA_VERSION}" "${CARLA_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# wine bootstrap (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
