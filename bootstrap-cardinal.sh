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

export PAWPAW_SKIP_SAMPLERATE=1

./bootstrap-common.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# file/magic (posix only)

if [ "${WIN32}" -eq 0 ]; then
    download file "${FILE_VERSION}" "ftp://ftp.astron.com/pub/file"
    build_autoconf file "${FILE_VERSION}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# glib

if [ "${MACOS}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    if [ "${WIN32}" -eq 1 ]; then
        GLIB_EXTRAFLAGS="--with-threads=win32"
    else
        GLIB_EXTRAFLAGS="--with-threads=posix"
    fi

    download glib ${GLIB_VERSION} "${GLIB_URL}" "${GLIB_TAR_EXT}"

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
#     elif [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ]; then
#         patch_file glib ${GLIB_VERSION} "gobject/Makefile.in" "s|glib_genmarshal = ./glib-genmarshal|glib_genmarshal = ${EXE_WRAPPER} ./glib-genmarshal.exe|"
    fi

    build_autoconfgen glib ${GLIB_VERSION} "--disable-rebuilds ${GLIB_EXTRAFLAGS}"
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

git_clone fluidsynth "${FLUIDSYNTH_VERSION}" "${FLUIDSYNTH_URL}"
patch_file fluidsynth "${FLUIDSYNTH_VERSION}" "CMakeLists.txt" 's/_init_lib_suffix "64"/_init_lib_suffix ""/'
build_cmake fluidsynth "${FLUIDSYNTH_VERSION}" "${FLUIDSYNTH_EXTRAFLAGS}"

if [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e" ]; then
    if [ "${MACOS}" -eq 1 ]; then
        sed -i -e 's/-lfluidsynth/-lfluidsynth -lglib-2.0 -lgthread-2.0 -lsndfile -lFLAC -lvorbisenc -lvorbis -lopus -logg -lpthread -liconv -lm/' "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc"
    elif [ "${WIN32}" -eq 1 ]; then
        sed -i -e 's/-L${libdir} -lfluidsynth/-L${libdir}  -lfluidsynth -lglib-2.0 -lgthread-2.0 -lsndfile -lFLAC -lvorbisenc -lvorbis -lopus -logg -lpthread -lm -lole32 -lws2_32/' "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc"
        touch "${PAWPAW_PREFIX}/lib/pkgconfig/fluidsynth.pc-e"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# wine bootstrap for python (needed for cross-compilation)

if [ "${WIN32}" -eq 1 ] && [ -n "${EXE_WRAPPER}" ] && [ ! -d "${WINEPREFIX}" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
