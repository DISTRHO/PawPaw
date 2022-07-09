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
# skip fluidsynth if glib is not wanted (fluidsynth requires glib)

if [ -n "${PAWPAW_SKIP_GLIB}" ]; then
    PAWPAW_SKIP_FLUIDSYNTH=1
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

if [ -z "${PAWPAW_SKIP_FFTW}" ]; then

# fftw is not compatible with LTO
if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    export EXTRA_CFLAGS="-fno-lto"
    export EXTRA_LDFLAGS="-fno-lto"
fi

FFTW_EXTRAFLAGS="--disable-alloca --disable-fortran --with-our-malloc"

if [ "${TOOLCHAIN_PREFIX}" = "aarch64-linux-gnu" ]; then
    FFTW_EXTRAFLAGS+=" --with-slow-timer"
    FFTW_EXTRAFLAGS+=" --enable-neon"
elif [ "${TOOLCHAIN_PREFIX}" = "arm-linux-gnueabihf" ]; then
    FFTW_EXTRAFLAGS+=" --with-slow-timer"
elif [ "${WASM}" -eq 1 ]; then
    FFTW_EXTRAFLAGS+=" --with-slow-timer"
# FIXME macos-universal proper optimizations
elif [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
    FFTW_EXTRAFLAGS+=" --enable-sse2"
fi

download fftw "${FFTW_VERSION}" "${FFTW_URL}"
build_autoconf fftw "${FFTW_VERSION}" "${FFTW_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make fftw "${FFTW_VERSION}" check
fi

fi # PAWPAW_SKIP_FFTW

# ---------------------------------------------------------------------------------------------------------------------
# fftwf

if [ -z "${PAWPAW_SKIP_FFTW}" ]; then

# fftw is not compatible with LTO
if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    export EXTRA_CFLAGS="-fno-lto"
    export EXTRA_LDFLAGS="-fno-lto"
fi

FFTWF_EXTRAFLAGS="${FFTW_EXTRAFLAGS} --enable-single"

if [ "${TOOLCHAIN_PREFIX}" = "aarch64-linux-gnu" ] || [ "${TOOLCHAIN_PREFIX}" = "arm-linux-gnueabihf" ]; then
    FFTWF_EXTRAFLAGS+=" --with-slow-timer"
    FFTWF_EXTRAFLAGS+=" --enable-neon"
fi

copy_download fftw fftwf "${FFTW_VERSION}"
build_autoconf fftwf "${FFTW_VERSION}" "${FFTWF_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make fftwf "${FFTW_VERSION}" check
fi

fi # PAWPAW_SKIP_FFTW

# ---------------------------------------------------------------------------------------------------------------------
# pcre

if [ "${MACOS}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    download pcre "${PCRE_VERSION}" "${PCRE_URL}"
    build_autoconf pcre "${PCRE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libffi

if [ "${WIN32}" -eq 1 ]; then
    LIBFFI_EXTRAFLAGS="--disable-multi-os-directory --disable-raw-api"

    download libffi "${LIBFFI_VERSION}" "${LIBFFI_URL}"
    build_autoconf libffi "${LIBFFI_VERSION}" "${LIBFFI_EXTRAFLAGS}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# glib

if [ -z "${PAWPAW_SKIP_GLIB}" ]; then

if [ "${MACOS}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    GLIB_EXTRAFLAGS="--disable-rebuilds"

    if [ "${WIN32}" -eq 1 ]; then
        GLIB_EXTRAFLAGS+=" --with-threads=win32"
    else
        GLIB_EXTRAFLAGS+=" --with-threads=posix"
    fi

    if [ "${MACOS}" -eq 1 ]; then
        export EXTRA_LDFLAGS="-lresolv"
    elif [ "${WIN32}" -eq 1 ]; then
        export EXTRA_CFLAGS="-Wno-format -Wno-format-overflow"
    fi

    download glib ${GLIB_VERSION} "${GLIB_URL}" "${GLIB_TAR_EXT}"

    if [ "${MACOS}" -eq 1 ]; then
        patch_file glib ${GLIB_VERSION} "glib/gconvert.c" '/#error/g'
        patch_file glib ${GLIB_VERSION} "glib/gatomic.c" 's/G_ATOMIC_ARM/__aarch64__/'
        patch_file glib ${GLIB_VERSION} "glib/gatomic.c" 's/G_ATOMIC_X86_64/__SSE2__/'
    fi

    build_autoconfgen glib ${GLIB_VERSION} "${GLIB_EXTRAFLAGS}"
fi

fi # PAWPAW_SKIP_GLIB

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

# FIXME tests fail on macOS
if [ "${CROSS_COMPILING}" -eq 0 ] && [ "${MACOS}" -eq 0 ]; then
    run_make liblo "${LIBLO_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# lv2

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

git_clone lv2 "${LV2_VERSION}" "${LV2_URL}"
build_waf lv2 "${LV2_VERSION}" "--lv2dir=${PAWPAW_PREFIX}/lib/lv2 --no-coverage --no-plugins"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# serd

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

download serd "${SERD_VERSION}" "${SERD_URL}" "tar.bz2"
build_waf serd "${SERD_VERSION}" "--static --no-shared --no-utils"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# sord

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

if [ "${CROSS_COMPILING}" -eq 1 ] && [ -z "${EXE_WRAPPER}" ]; then
    SORD_EXTRAFLAGS="--no-utils"
fi

download sord "${SORD_VERSION}" "${SORD_URL}" "tar.bz2"
build_waf sord "${SORD_VERSION}" "--static --no-shared ${SORD_EXTRAFLAGS}"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# sratom

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

download sratom "${SRATOM_VERSION}" "${SRATOM_URL}" "tar.bz2"
build_waf sratom "${SRATOM_VERSION}" "--static --no-shared"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# lilv

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

download lilv "${LILV_VERSION}" "${LILV_URL}" "tar.bz2"
build_waf lilv "${LILV_VERSION}" "--static --no-bash-completion --no-bindings --no-shared"
# --static-progs

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# lv2lint

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

if [ "${LV2LINT_SUPPORTED}" -eq 1 ]; then
    download lv2lint "${LV2LINT_VERSION}" "${LV2LINT_URL}"
    build_meson lv2lint "${LV2LINT_VERSION}"
    # "-Donline-tests=true -Delf-tests=true"
fi

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# kxstudio lv2 extensions

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

git_clone kxstudio-lv2-extensions "${KXSTUDIO_LV2_EXTENSIONS_VERSION}" "${KXSTUDIO_LV2_EXTENSIONS_URL}"
build_make kxstudio-lv2-extensions "${KXSTUDIO_LV2_EXTENSIONS_VERSION}"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# MOD lv2 extensions

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

git_clone mod-sdk "${MOD_SDK_VERSION}" "${MOD_SDK_URL}"
build_make mod-sdk "${MOD_SDK_VERSION}"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# fluidsynth

# FIXME glib does not build yet
if [ "${WASM}" -eq 1 ]; then
    PAWPAW_SKIP_FLUIDSYNTH=1
fi

if [ -z "${PAWPAW_SKIP_FLUIDSYNTH}" ]; then

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
build_cmake fluidsynth "${FLUIDSYNTH_VERSION}" "${FLUIDSYNTH_EXTRAFLAGS}"

if [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e" ]; then
    FLUIDSYNTH_EXTRALIBS="-lglib-2.0 -lgthread-2.0 -lsndfile -lFLAC -lvorbisenc -lvorbis -lopus -logg -lpthread -lm"
    if [ "${MACOS}" -eq 1 ]; then
        FLUIDSYNTH_EXTRALIBS+=" -liconv"
    elif [ "${WIN32}" -eq 1 ]; then
        FLUIDSYNTH_EXTRALIBS+=" -lole32 -lws2_32"
    fi
    sed -i -e "s/-L\${libdir} -lfluidsynth/-L\${libdir}  -lfluidsynth ${FLUIDSYNTH_EXTRALIBS}/" "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc"
    touch "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e"
fi

fi # PAWPAW_SKIP_FLUIDSYNTH

# ---------------------------------------------------------------------------------------------------------------------
# mxml

git_clone mxml "${MXML_VERSION}" "${MXML_URL}"
build_autoconf mxml "${MXML_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# carla (backend only)

if [ "${CROSS_COMPILING}" -eq 0 ] || [ -n "${EXE_WRAPPER}" ]; then

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
CARLA_EXTRAFLAGS+=" HAVE_SDL=false"
CARLA_EXTRAFLAGS+=" HAVE_SNDFILE=false"
CARLA_EXTRAFLAGS+=" NOOPT=true"
CARLA_EXTRAFLAGS+=" USING_JUCE=false"
CARLA_EXTRAFLAGS+=" USING_JUCE_AUDIO_DEVICES=false"
CARLA_EXTRAFLAGS+=" USING_JUCE_GUI_EXTRA=false"
CARLA_EXTRAFLAGS+=" USING_RTAUDIO=false"

git_clone carla "${CARLA_VERSION}" "${CARLA_URL}"
build_make carla "${CARLA_VERSION}" "${CARLA_EXTRAFLAGS}"

fi

# ---------------------------------------------------------------------------------------------------------------------
# wine bootstrap (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
