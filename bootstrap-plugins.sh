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
# libpng

LIBPNG_EXTRAFLAGS=""

# bypass broken zlib configure tests
if [ "${MACOS}" -eq 0 ]; then
    LIBPNG_EXTRAFLAGS+=" ac_cv_lib_z_zlibVersion=yes"
    export EXTRA_CPPFLAGS="-I${PAWPAW_PREFIX}/include"
fi

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    # FIXME
    LIBPNG_EXTRAFLAGS+=" --disable-hardware-optimizations"
fi

download libpng "${LIBPNG_VERSION}" "${LIBPNG_URL}" "tar.xz"
build_autoconf libpng "${LIBPNG_VERSION}" "${LIBPNG_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make libpng "${LIBPNG_VERSION}" "check -j 1"
fi

if [ "${MACOS}" -eq 1 ] && [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/libpng16.pc-e" ]; then
    sed -i -e '/Requires.private: zlib/d' "${PAWPAW_PREFIX}/lib/pkgconfig/libpng16.pc"
    touch "${PAWPAW_PREFIX}/lib/pkgconfig/libpng16.pc-e"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libxml2

if [ "${MACOS}" -eq 0 ]; then

LIBXML2_EXTRAFLAGS=""

# ensure no system paths are used
LIBXML2_EXTRAFLAGS+=" -DZLIB_INCLUDE_DIR:PATH=${PAWPAW_PREFIX}/include"
LIBXML2_EXTRAFLAGS+=" -DZLIB_LIBRARY:PATH=${PAWPAW_PREFIX}/lib/libz.a"

# disable stuff typically not needed for plugins
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_HTML=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_HTTP=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_ICONV=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_LZMA=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_MODULES=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_PROGRAMS=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_PYTHON=OFF"
LIBXML2_EXTRAFLAGS+=" -DLIBXML2_WITH_THREADS=OFF"

download libxml2 "${LIBXML2_VERSION}" "${LIBXML2_URL}" "tar.xz"
build_cmake libxml2 "${LIBXML2_VERSION}" "${LIBXML2_EXTRAFLAGS}"

fi # !MACOS

# ---------------------------------------------------------------------------------------------------------------------
# pixman

PIXMAN_EXTRAFLAGS="--disable-gtk  --enable-libpng"

download pixman "${PIXMAN_VERSION}" "${PIXMAN_URL}"
build_autoconf pixman "${PIXMAN_VERSION}" "${PIXMAN_EXTRAFLAGS}"

if [ "${CROSS_COMPILING}" -eq 0 ]; then
    run_make pixman "${PIXMAN_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# freetype

FREETYPE_EXTRAFLAGS=""
FREETYPE_EXTRAFLAGS+=" -DFT_REQUIRE_PNG=TRUE"
FREETYPE_EXTRAFLAGS+=" -DFT_REQUIRE_ZLIB=TRUE"

FREETYPE_EXTRAFLAGS+=" -DFT_DISABLE_BROTLI=TRUE"
FREETYPE_EXTRAFLAGS+=" -DFT_DISABLE_BZIP2=TRUE"
FREETYPE_EXTRAFLAGS+=" -DFT_DISABLE_HARFBUZZ=TRUE"

# ensure no system paths are used
# FREETYPE_EXTRAFLAGS+=" -DBROTLIDEC_INCLUDE_DIRS:PATH=${PAWPAW_PREFIX}/include"
# FREETYPE_EXTRAFLAGS+=" -DFREETYPE_INCLUDE_DIRS:PATH=${PAWPAW_PREFIX}/include"
# FREETYPE_EXTRAFLAGS+=" -DHarfBuzz_INCLUDE_DIR:PATH=${PAWPAW_PREFIX}/include/harfbuzz"
FREETYPE_EXTRAFLAGS+=" -DPNG_INCLUDE_DIR:PATH=${PAWPAW_PREFIX}/include"

if [ "${MACOS}" -eq 0 ]; then
    FREETYPE_EXTRAFLAGS+=" -DZLIB_INCLUDE_DIR:PATH=${PAWPAW_PREFIX}/include"
    FREETYPE_EXTRAFLAGS+=" -DZLIB_LIBRARY:PATH=${PAWPAW_PREFIX}/lib/libz.a"
fi

download freetype "${FREETYPE_VERSION}" "${FREETYPE_URL}" "tar.xz"
build_cmake freetype "${FREETYPE_VERSION}" "${FREETYPE_EXTRAFLAGS}"

if [ ! -e "${PAWPAW_PREFIX}/lib/pkgconfig/freetype2.pc-e" ]; then
    sed -i -e 's/, libbrotlidec//' "${PAWPAW_PREFIX}/lib/pkgconfig/freetype2.pc"
    if [ "${MACOS}" -eq 1 ]; then
        sed -i -e 's/Requires:  zlib,/Requires:/' "${PAWPAW_PREFIX}/lib/pkgconfig/freetype2.pc"
    fi
    touch "${PAWPAW_PREFIX}/lib/pkgconfig/freetype2.pc-e"
fi

# ---------------------------------------------------------------------------------------------------------------------
# fontconfig

FONTCONFIG_EXTRAFLAGS="--disable-iconv"

if [ "${MACOS}" -eq 0 ]; then
    FONTCONFIG_EXTRAFLAGS+=" --enable-libxml2"
fi

download fontconfig "${FONTCONFIG_VERSION}" "${FONTCONFIG_URL}"
build_autoconf fontconfig "${FONTCONFIG_VERSION}" "${FONTCONFIG_EXTRAFLAGS}"

# tests fail on stable release, see https://gitlab.freedesktop.org/fontconfig/fontconfig/-/issues/177
# if [ "${CROSS_COMPILING}" -eq 0 ]; then
#     run_make fontconfig "${FONTCONFIG_VERSION}" check
# fi

# ---------------------------------------------------------------------------------------------------------------------
# cairo

CAIRO_EXTRAFLAGS="ac_cv_lib_z_compress=yes"
CAIRO_EXTRAFLAGS+=" --disable-gtk-doc"
CAIRO_EXTRAFLAGS+=" --disable-qt"
CAIRO_EXTRAFLAGS+=" --disable-os2"
CAIRO_EXTRAFLAGS+=" --disable-beos"
CAIRO_EXTRAFLAGS+=" --disable-drm"
CAIRO_EXTRAFLAGS+=" --disable-gallium"
CAIRO_EXTRAFLAGS+=" --disable-gl"
CAIRO_EXTRAFLAGS+=" --disable-glesv2"
CAIRO_EXTRAFLAGS+=" --disable-glesv3"
CAIRO_EXTRAFLAGS+=" --disable-cogl"
CAIRO_EXTRAFLAGS+=" --disable-directfb"
CAIRO_EXTRAFLAGS+=" --disable-vg"
CAIRO_EXTRAFLAGS+=" --disable-egl"
CAIRO_EXTRAFLAGS+=" --disable-glx"
CAIRO_EXTRAFLAGS+=" --disable-wgl"
CAIRO_EXTRAFLAGS+=" --disable-script"
CAIRO_EXTRAFLAGS+=" --disable-ps"
CAIRO_EXTRAFLAGS+=" --disable-pdf"
CAIRO_EXTRAFLAGS+=" --disable-svg"
CAIRO_EXTRAFLAGS+=" --disable-test-surfaces"
CAIRO_EXTRAFLAGS+=" --disable-svg"
CAIRO_EXTRAFLAGS+=" --disable-tee"
CAIRO_EXTRAFLAGS+=" --disable-xml"
CAIRO_EXTRAFLAGS+=" --disable-gobject"
CAIRO_EXTRAFLAGS+=" --disable-full-testing"

CAIRO_EXTRAFLAGS+=" --enable-interpreter"
CAIRO_EXTRAFLAGS+=" --enable-png"
CAIRO_EXTRAFLAGS+=" --enable-ft"
CAIRO_EXTRAFLAGS+=" --enable-pthread"

# TESTING
CAIRO_EXTRAFLAGS+=" --disable-symbol-lookup"
CAIRO_EXTRAFLAGS+=" --disable-trace"

if [ "${LINUX}" -eq 1 ]; then
    CAIRO_EXTRAFLAGS+=" --enable-fc"
    CAIRO_EXTRAFLAGS+=" --enable-xlib"
    CAIRO_EXTRAFLAGS+=" --enable-xlib-xrender"
    # TODO
    # CAIRO_EXTRAFLAGS+=" --enable-xcb"
    # CAIRO_EXTRAFLAGS+=" --enable-xlib-xcb"
    # CAIRO_EXTRAFLAGS+=" --enable-xcb-shm"
    CAIRO_EXTRAFLAGS+=" --disable-xcb"
    CAIRO_EXTRAFLAGS+=" --disable-xlib-xcb"
    CAIRO_EXTRAFLAGS+=" --disable-xcb-shm"
    if [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
        CAIRO_EXTRAFLAGS+=" ax_cv_c_float_words_bigendian=yes"
    else
        CAIRO_EXTRAFLAGS+=" ax_cv_c_float_words_bigendian=no"
    fi
else
    CAIRO_EXTRAFLAGS+=" --disable-fc"
    CAIRO_EXTRAFLAGS+=" --disable-xlib"
    CAIRO_EXTRAFLAGS+=" --disable-xlib-xrender"
    CAIRO_EXTRAFLAGS+=" --disable-xcb"
    CAIRO_EXTRAFLAGS+=" --disable-xlib-xcb"
    CAIRO_EXTRAFLAGS+=" --disable-xcb-shm"
fi

if [ "${MACOS}" -eq 1 ]; then
    CAIRO_EXTRAFLAGS+=" --enable-quartz"
    CAIRO_EXTRAFLAGS+=" --enable-quartz-font"
    CAIRO_EXTRAFLAGS+=" --enable-quartz-image"
else
    CAIRO_EXTRAFLAGS+=" --disable-quartz"
    CAIRO_EXTRAFLAGS+=" --disable-quartz-font"
    CAIRO_EXTRAFLAGS+=" --disable-quartz-image"
fi

if [ "${WIN32}" -eq 1 ]; then
    CAIRO_EXTRAFLAGS+=" --enable-win32"
    CAIRO_EXTRAFLAGS+=" --enable-win32-font"
    CAIRO_EXTRAFLAGS+=" ax_cv_c_float_words_bigendian=no"
else
    CAIRO_EXTRAFLAGS+=" --disable-win32"
    CAIRO_EXTRAFLAGS+=" --disable-win32-font"
fi

if [ "${MACOS}" -eq 1 ]; then
    # fix link of test suite
    export EXTRA_LDFLAGS="-framework CoreFoundation -framework CoreGraphics"
fi

download cairo "${CAIRO_VERSION}" "${CAIRO_URL}" "tar.xz"
build_autoconf cairo "${CAIRO_VERSION}" "${CAIRO_EXTRAFLAGS}"

# FIXME tests are failing :(
# if [ "${CROSS_COMPILING}" -eq 0 ]; then
#     run_make cairo "${CAIRO_VERSION}" "check -j 1"
# fi

# ---------------------------------------------------------------------------------------------------------------------
# fftw

if [ -z "${PAWPAW_SKIP_FFTW}" ]; then

# fftw is not compatible with LTO
if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    export EXTRA_CFLAGS="-fno-lto"
    export EXTRA_LDFLAGS="-fno-lto"
fi

FFTW_EXTRAFLAGS="--disable-alloca --disable-fortran --with-our-malloc"

if [ "${LINUX}" -eq 1 ]; then
    if [ "${LINUX_TARGET}" = "linux-aarch64" ]; then
        FFTW_EXTRAFLAGS+=" --with-slow-timer --enable-neon"
    elif [ "${LINUX_TARGET}" = "linux-armhf" ]; then
        FFTW_EXTRAFLAGS+=" --with-slow-timer"
    elif [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
        FFTW_EXTRAFLAGS+=" --with-slow-timer"
    fi
elif [ "${WASM}" -eq 1 ]; then
    FFTW_EXTRAFLAGS+=" --with-slow-timer"
# FIXME macos-universal proper optimizations
# https://github.com/DISTRHO/PawPaw/issues/3
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

if [ "${LINUX}" -eq 1 ] && [ "${LINUX_TARGET}" = "linux-armhf" ]; then
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

if [ "${MACOS}" -eq 1 ] || [ -n "${TOOLCHAIN_PREFIX}" ]; then
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

if [ "${MACOS}" -eq 1 ] || [ "${WASM}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    GLIB_EXTRAFLAGS="--disable-rebuilds"

    if [ "${WIN32}" -eq 1 ]; then
        GLIB_EXTRAFLAGS+=" --with-threads=win32"
    else
        GLIB_EXTRAFLAGS+=" --with-threads=posix"
    fi

    if [ "${WASM}" -eq 1 ]; then
        GLIB_EXTRAFLAGS+=" ac_cv_lib_socket_socket=no ac_cv_func_posix_getgrgid_r=no ac_cv_func_posix_getpwuid_r=no glib_cv_stack_grows=no glib_cv_uscore=no"
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
    elif [ "${WASM}" -eq 1 ]; then
        patch_file glib ${GLIB_VERSION} "glib/gatomic.c" 's/G_ATOMIC_X86_64/_G_ATOMIC_NOT_X86_64/'
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
# serd

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

if [ "${CROSS_COMPILING}" -eq 1 ] && [ "${LINUX}" -eq 0 ] && [ -z "${EXE_WRAPPER}" ]; then
    SERD_EXTRAFLAGS="-Dtools=disabled"
fi

download serd "${SERD_VERSION}" "${SERD_URL}" "tar.xz"
build_meson serd "${SERD_VERSION}" "-Ddefault_library=static -Ddocs=disabled ${SERD_EXTRAFLAGS}"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# sord

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

if [ "${CROSS_COMPILING}" -eq 1 ] && [ "${LINUX}" -eq 0 ] && [ -z "${EXE_WRAPPER}" ]; then
    SORD_EXTRAFLAGS="-Dtools=disabled"
fi

download sord "${SORD_VERSION}" "${SORD_URL}" "tar.xz"
build_meson sord "${SORD_VERSION}" "-Ddefault_library=static -Ddocs=disabled ${SORD_EXTRAFLAGS}"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# lv2

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

git_clone lv2 "${LV2_VERSION}" "${LV2_URL}"
build_meson lv2 "${LV2_VERSION}" "-Dlv2dir=${PAWPAW_PREFIX}/lib/lv2 -Dplugins=disabled"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# sratom

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

download sratom "${SRATOM_VERSION}" "${SRATOM_URL}" "tar.xz"
build_meson sratom "${SRATOM_VERSION}" "-Ddefault_library=static -Ddocs=disabled"

fi # PAWPAW_SKIP_LV2

# ---------------------------------------------------------------------------------------------------------------------
# lilv

if [ -z "${PAWPAW_SKIP_LV2}" ]; then

if [ "${CROSS_COMPILING}" -eq 1 ] && [ "${LINUX}" -eq 0 ]; then
    LILV_EXTRAFLAGS="-Dtests=disabled -Dtools=disabled"
fi

download lilv "${LILV_VERSION}" "${LILV_URL}" "tar.xz"
build_meson lilv "${LILV_VERSION}" "-Ddefault_library=static -Dbindings_py=disabled -Ddocs=disabled ${LILV_EXTRAFLAGS}"

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

if [ "${CROSS_COMPILING}" -eq 0 ] || [ "${LINUX}" -eq 1 ]; then

CARLA_EXTRAFLAGS="CAN_GENERATE_LV2_TTL=false"
CARLA_EXTRAFLAGS+=" EXTERNAL_PLUGINS=false"
CARLA_EXTRAFLAGS+=" HAVE_ALSA=false"
CARLA_EXTRAFLAGS+=" HAVE_JACK=false"
CARLA_EXTRAFLAGS+=" HAVE_PULSEAUDIO=false"
CARLA_EXTRAFLAGS+=" HAVE_DGL=false"
CARLA_EXTRAFLAGS+=" HAVE_HYLIA=false"
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

if [ "${EXE_WRAPPER}" = "wine" ]; then
    wineboot -u
fi

# ---------------------------------------------------------------------------------------------------------------------
