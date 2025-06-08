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
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# check for depedencies

if ! command -v curl >/dev/null; then
    echo "missing 'curl' program, cannot continue!"
    exit 2
fi

if ! command -v make >/dev/null; then
    echo "missing 'make' program, cannot continue!"
    exit 2
fi

if ! command -v patch >/dev/null; then
    echo "missing 'patch' program, cannot continue!"
    exit 2
fi

if ! command -v python3 >/dev/null; then
    echo "missing 'python3' program, cannot continue!"
    exit 2
fi

if ! command -v sed >/dev/null; then
    echo "missing 'sed' program, cannot continue!"
    exit 2
fi

if ! command -v tar >/dev/null; then
    echo "missing 'tar' program, cannot continue!"
    exit 2
fi

if [ "${LINUX}" -eq 1 ] && ! command -v pkg-config >/dev/null; then
    echo "missing 'pkg-config' program, cannot continue!"
    exit 2
fi

if [ -z "${cmake}" ]; then
    echo "missing 'cmake' program, cannot continue!"
    exit 2
fi

# ---------------------------------------------------------------------------------------------------------------------
# create common directories

mkdir -p "${PAWPAW_BUILDDIR}"
mkdir -p "${PAWPAW_DOWNLOADDIR}"
mkdir -p "${PAWPAW_PREFIX}"
mkdir -p "${PAWPAW_TMPDIR}"

# ---------------------------------------------------------------------------------------------------------------------
# merged usr mode

mkdir -p "${PAWPAW_PREFIX}/bin"
mkdir -p "${PAWPAW_PREFIX}/docs"
mkdir -p "${PAWPAW_PREFIX}/etc"
mkdir -p "${PAWPAW_PREFIX}/include"
mkdir -p "${PAWPAW_PREFIX}/lib"
mkdir -p "${PAWPAW_PREFIX}/share"
mkdir -p "${PAWPAW_PREFIX}/usr"

if [ ! -e "${PAWPAW_PREFIX}/usr/bin" ]; then
    ln -s ../bin "${PAWPAW_PREFIX}/usr/bin"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/docs" ]; then
    ln -s ../docs "${PAWPAW_PREFIX}/usr/docs"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/etc" ]; then
    ln -s ../etc "${PAWPAW_PREFIX}/usr/etc"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/include" ]; then
    ln -s ../include "${PAWPAW_PREFIX}/usr/include"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/lib" ]; then
    ln -s ../lib "${PAWPAW_PREFIX}/usr/lib"
fi
if [ ! -e "${PAWPAW_PREFIX}/usr/share" ]; then
    ln -s ../share "${PAWPAW_PREFIX}/usr/share"
fi

# ---------------------------------------------------------------------------------------------------------------------
# merged usr mode (host)

mkdir -p "${PAWPAW_PREFIX}-host/bin"
mkdir -p "${PAWPAW_PREFIX}-host/usr"

if [ ! -e "${PAWPAW_PREFIX}-host/usr/bin" ]; then
    ln -s ../bin "${PAWPAW_PREFIX}-host/usr/bin"
fi

# ---------------------------------------------------------------------------------------------------------------------
# GNU tools by default on macOS

if [ "${MACOS}" -eq 1 ]; then
    if ! command -v gawk >/dev/null; then
        echo "missing 'gawk' program, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/awk" ]; then
        ln -s $(command -v gawk) "${PAWPAW_PREFIX}-host/bin/awk"
    fi

    if ! command -v gcp >/dev/null; then
        echo "missing 'gcp' program, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/cp" ]; then
        ln -s $(command -v gcp) "${PAWPAW_PREFIX}-host/bin/cp"
    fi

    if ! command -v ginstall >/dev/null; then
        echo "missing 'ginstall' program, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/install" ]; then
        ln -s $(command -v ginstall) "${PAWPAW_PREFIX}-host/bin/install"
    fi

    if ! command -v glibtool >/dev/null; then
        echo "missing 'glibtool' program, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/libtool" ]; then
        ln -s $(command -v glibtool) "${PAWPAW_PREFIX}-host/bin/libtool"
    fi

    if ! command -v glibtoolize >/dev/null; then
        echo "missing 'glibtoolize' program, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/libtoolize" ]; then
        ln -s $(command -v glibtoolize) "${PAWPAW_PREFIX}-host/bin/libtoolize"
    fi

    if ! command -v gm4 >/dev/null; then
        echo "missing 'curl' gm4, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/m4" ]; then
        ln -s $(command -v gm4) "${PAWPAW_PREFIX}-host/bin/m4"
    fi

    if ! command -v gmake >/dev/null; then
        echo "missing 'curl' gmake, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/make" ]; then
        ln -s $(command -v gmake) "${PAWPAW_PREFIX}-host/bin/make"
    fi

    if ! command -v greadlink >/dev/null; then
        echo "missing 'curl' greadlink, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/readlink" ]; then
        ln -s $(command -v greadlink) "${PAWPAW_PREFIX}-host/bin/readlink"
    fi

    if ! command -v grealpath >/dev/null; then
        echo "missing 'curl' grealpath, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/realpath" ]; then
        ln -s $(command -v grealpath) "${PAWPAW_PREFIX}-host/bin/realpath"
    fi

    if ! command -v gsed >/dev/null; then
        echo "missing 'curl' gsed, cannot continue!"
        exit 2
    elif [ ! -e "${PAWPAW_PREFIX}-host/bin/sed" ]; then
        ln -s $(command -v gsed) "${PAWPAW_PREFIX}-host/bin/sed"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# use some native libs for linux builds

if [ "${LINUX}" -eq 1 ]; then
    mkdir -p ${TARGET_PKG_CONFIG_PATH}
    if [ "${LINUX_TARGET}" = "linux-aarch64" ]; then
        export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-armhf" ]; then
        export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-i686" ]; then
        export PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
        export PKG_CONFIG_PATH=/usr/lib/riscv64-linux-gnu/pkgconfig
    elif [ "${LINUX_TARGET}" = "linux-x86_64" ]; then
        export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig
    fi
    if ! pkg-config --print-errors --exists alsa dbus-1 gl glib-2.0 libpcre libpcre2-8 pthread-stubs uuid x11 xcb xcb-dri2 xcursor xdamage xext xfixes xproto xrandr xrender xxf86vm; then
        echo "some system libs are not available, cannot continue"
        exit 2
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/alsa.pc" ]; then
        cp $(pkg-config --variable=pcfiledir alsa)/alsa.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/alsa.pc
    fi
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
        sed -i '/Libs.private/d;/Requires.private/d' ${TARGET_PKG_CONFIG_PATH}/g{io,lib,module,object,thread}-2.0.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/libpcre.pc" ]; then
        cp $(pkg-config --variable=pcfiledir libpcre)/libpcre.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/libpcre.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/libpcre2-8.pc" ]; then
        cp $(pkg-config --variable=pcfiledir libpcre2-8)/libpcre2-8.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/libpcre2-8.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/pthread-stubs.pc" ]; then
        cp $(pkg-config --variable=pcfiledir pthread-stubs)/pthread-stubs.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/pthread-stubs.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/uuid.pc" ]; then
        cp $(pkg-config --variable=pcfiledir uuid)/uuid.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/uuid.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/x11.pc" ]; then
        cp $(pkg-config --variable=pcfiledir x11)/x11.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/x11.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xcb.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xcb)/{xau,xcb,xdmcp}.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/{xau,xcb,xdmcp}.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xcb-dri2.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xcb-dri2)/xcb-dri2.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xcb-dri2.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xcursor.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xcursor)/xcursor.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xcursor.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xdamage.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xdamage)/xdamage.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xdamage.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xext.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xext)/xext.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xext.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xf86vidmodeproto.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xf86vidmodeproto)/xf86vidmodeproto.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xf86vidmodeproto.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xfixes.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xfixes)/xfixes.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xfixes.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xproto.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xproto)/{damageproto,fixesproto,kbproto,randrproto,renderproto,xextproto,xproto}.pc ${TARGET_PKG_CONFIG_PATH}/
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
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/xxf86vm.pc" ]; then
        cp $(pkg-config --variable=pcfiledir xxf86vm)/xxf86vm.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/xxf86vm.pc
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# pkgconfig

export EXTRA_CFLAGS="-Wno-int-conversion"

download pkg-config "${PKG_CONFIG_VERSION}" "${PKG_CONFIG_URL}"
build_host_autoconf pkg-config "${PKG_CONFIG_VERSION}" "--enable-indirect-deps --with-internal-glib --with-pc-path=${TARGET_PKG_CONFIG_PATH}"

if [ -n "${TOOLCHAIN_PREFIX_}" ] && [ ! -e "${PAWPAW_PREFIX}/bin/${TOOLCHAIN_PREFIX_}pkg-config" ]; then
    ln -s pkg-config "${PAWPAW_PREFIX}/bin/${TOOLCHAIN_PREFIX_}pkg-config"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libogg

download libogg "${LIBOGG_VERSION}" "${LIBOGG_URL}"
build_autoconf libogg "${LIBOGG_VERSION}"

if [ -z "${PAWPAW_SKIP_TESTS}" ] || [ "${PAWPAW_SKIP_TESTS}" -eq 0 ]; then
    run_make libogg "${LIBOGG_VERSION}" "check -j 1"
fi

# ---------------------------------------------------------------------------------------------------------------------
# libvorbis

LIBVORBIS_EXTRAFLAGS="--disable-examples"

download libvorbis "${LIBVORBIS_VERSION}" "${LIBVORBIS_URL}"
build_autoconf libvorbis "${LIBVORBIS_VERSION}" "${LIBVORBIS_EXTRAFLAGS}"

if [ -z "${PAWPAW_SKIP_TESTS}" ] || [ "${PAWPAW_SKIP_TESTS}" -eq 0 ]; then
    run_make libvorbis "${LIBVORBIS_VERSION}" "check -j 1"
fi

# ---------------------------------------------------------------------------------------------------------------------
# flac

FLAC_EXTRAFLAGS=""
FLAC_EXTRAFLAGS+=" --disable-doxygen-docs"
FLAC_EXTRAFLAGS+=" --disable-examples"
FLAC_EXTRAFLAGS+=" --disable-stack-smash-protection"
FLAC_EXTRAFLAGS+=" --disable-thorough-tests"
FLAC_EXTRAFLAGS+=" --disable-xmms-plugin"

if [ -n "${PAWPAW_NOSIMD}" ] && [ "${PAWPAW_NOSIMD}" -eq 1 ]; then
    FLAC_EXTRAFLAGS+=" ac_cv_header_x86intrin_h=no ac_cv_header_arm_neon_h=no asm_opt=no"
elif [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
    # FIXME
    FLAC_EXTRAFLAGS+=" ac_cv_header_x86intrin_h=no ac_cv_header_arm_neon_h=no asm_opt=no"
else
    # force intrinsic optimizations on targets where auto-detection fails
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        FLAC_EXTRAFLAGS+=" ac_cv_header_x86intrin_h=yes ac_cv_header_arm_neon_h=yes asm_opt=yes"
    elif [ "${WASM}" -eq 1 ]; then
        FLAC_EXTRAFLAGS+=" ac_cv_header_x86intrin_h=yes asm_opt=yes"
    fi
fi

download flac "${FLAC_VERSION}" "${FLAC_URL}" "tar.xz"
build_autoconf flac "${FLAC_VERSION}" "${FLAC_EXTRAFLAGS}"

if [ -z "${PAWPAW_SKIP_TESTS}" ] || [ "${PAWPAW_SKIP_TESTS}" -eq 0 ]; then
    run_make flac "${FLAC_VERSION}" "check -j 1"
fi

# ---------------------------------------------------------------------------------------------------------------------
# opus

OPUS_EXTRAFLAGS="--enable-custom-modes --enable-float-approx"
OPUS_EXTRAFLAGS+=" --disable-stack-protector"

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-extra-programs"
fi

if [ -n "${PAWPAW_NOSIMD}" ] && [ "${PAWPAW_NOSIMD}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-intrinsics"
# FIXME macos-universal proper optimizations https://github.com/DISTRHO/PawPaw/issues/4
elif [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
    OPUS_EXTRAFLAGS+=" --disable-intrinsics"
fi

download opus "${OPUS_VERSION}" "${OPUS_URL}"
build_autoconf opus "${OPUS_VERSION}" "${OPUS_EXTRAFLAGS}"

if [ -z "${PAWPAW_SKIP_TESTS}" ] || [ "${PAWPAW_SKIP_TESTS}" -eq 0 ]; then
    run_make opus "${OPUS_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# libsndfile

LIBSNDFILE_EXTRAFLAGS="--disable-alsa --disable-full-suite --disable-sqlite"

# force disable mp3 support for now, until we handle those libs
LIBSNDFILE_EXTRAFLAGS+=" --disable-mpeg"

# force intrinsic optimizations on some targets
if [ -z "${PAWPAW_NOSIMD}" ] || [ "${PAWPAW_NOSIMD}" -eq 0 ]; then
    if [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WASM}" -eq 1 ]; then
        LIBSNDFILE_EXTRAFLAGS+=" ac_cv_header_immintrin_h=yes"
    fi
fi

# fix build, regex matching fails
if [ "${WASM}" -eq 1 ]; then
    LIBSNDFILE_EXTRAFLAGS+=" ax_cv_c_compiler_version=15.0.0"
    LIBSNDFILE_EXTRAFLAGS+=" ax_cv_cxx_compiler_version=15.0.0"
fi

# otherwise tests fail
export EXTRA_CFLAGS="-fno-associative-math -frounding-math"

if [ "${CLANG}" -eq 1 ]; then
    export EXTRA_CFLAGS+=" -fno-reciprocal-math"
else
    export EXTRA_CFLAGS+=" -fsignaling-nans"
fi

download libsndfile "${LIBSNDFILE_VERSION}" "${LIBSNDFILE_URL}" "tar.xz"
build_autoconf libsndfile "${LIBSNDFILE_VERSION}" "${LIBSNDFILE_EXTRAFLAGS}"

if [ -z "${PAWPAW_SKIP_TESTS}" ] || [ "${PAWPAW_SKIP_TESTS}" -eq 0 ]; then
    run_make libsndfile "${LIBSNDFILE_VERSION}" check
fi

# ---------------------------------------------------------------------------------------------------------------------
# libsamplerate

if [ -z "${PAWPAW_SKIP_SAMPLERATE}" ] || [ "${PAWPAW_SKIP_SAMPLERATE}" -eq 0 ]; then

LIBSAMPLERATE_EXTRAFLAGS="--disable-fftw"

# NOTE: sndfile tests use Carbon, which is not always available on macOS
if [ "${CROSS_COMPILING}" -eq 1 ] || [ "${MACOS}" -eq 1 ]; then
    LIBSAMPLERATE_EXTRAFLAGS+=" --disable-sndfile"
fi

download libsamplerate "${LIBSAMPLERATE_VERSION}" "${LIBSAMPLERATE_URL}" "tar.xz"
build_autoconf libsamplerate "${LIBSAMPLERATE_VERSION}" "${LIBSAMPLERATE_EXTRAFLAGS}"

if ([ -z "${PAWPAW_SKIP_TESTS}" ] || [ "${PAWPAW_SKIP_TESTS}" -eq 0 ]) && [ "${MACOS}" -eq 0 ]; then
    run_make libsamplerate "${LIBSAMPLERATE_VERSION}" check
fi

fi # PAWPAW_SKIP_SAMPLERATE

# ---------------------------------------------------------------------------------------------------------------------
# zlib (skipped on macOS)

if [ "${MACOS}" -eq 0 ]; then
    download zlib "${ZLIB_VERSION}" "${ZLIB_URL}"
    build_conf zlib "${ZLIB_VERSION}" "--static --prefix=${PAWPAW_PREFIX} --zprefix"

    if [ "${CROSS_COMPILING}" -eq 0 ]; then
        run_make zlib "${ZLIB_VERSION}" check
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# mingw-std-threads (download, win32 only)

if [ "${WIN32}" -eq 1 ]; then
    git_clone mingw-std-threads "${MINGW_STD_THREADS_VERSION}" "${MINGW_STD_THREADS_URL}"
    if [ ! -e "${PAWPAW_BUILDDIR}/mingw-std-threads-${MINGW_STD_THREADS_VERSION}/.stamp-installed" ]; then
        install -m 644 "${PAWPAW_BUILDDIR}/mingw-std-threads-${MINGW_STD_THREADS_VERSION}"/mingw.*.h "${PAWPAW_PREFIX}/include/"
        install -m 644 "${PAWPAW_ROOT}/mingw-compat"/* "${PAWPAW_PREFIX}/include/"
        touch "${PAWPAW_BUILDDIR}/mingw-std-threads-${MINGW_STD_THREADS_VERSION}/.stamp-installed"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
