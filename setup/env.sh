#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------
# OS setup

if [ "${LINUX}" -eq 1 ]; then
    APP_EXT=""
    CMAKE_SYSTEM_NAME="Linux"
    PAWPAW_TARGET="linux"

elif [ "${MACOS}" -eq 1 ]; then
    APP_EXT=""
    CMAKE_SYSTEM_NAME="Darwin"
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        PAWPAW_TARGET="macos-universal"
    else
        PAWPAW_TARGET="macos"
    fi

elif [ "${WIN32}" -eq 1 ]; then
    APP_EXT=".exe"
    CMAKE_SYSTEM_NAME="Windows"
    if [ "${WIN64}" -eq 1 ]; then
        PAWPAW_TARGET="win64"
    else
        PAWPAW_TARGET="win32"
    fi

else
    echo "Unknown target '${target}'"
    if [ -z "${SOURCING_FILES}" ]; then
        exit 4
    else
        APP_EXT=""
        CMAKE_SYSTEM_NAME="Unknown"
        PAWPAW_TARGET="unknown"
        INVALID_TARGET=1
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# PawPaw setup

PAWPAW_DIR="${HOME}/PawPawBuilds"
PAWPAW_DOWNLOADDIR="${PAWPAW_DIR}/downloads"
PAWPAW_BUILDDIR="${PAWPAW_DIR}/builds/${PAWPAW_TARGET}"
PAWPAW_PREFIX="${PAWPAW_DIR}/targets/${PAWPAW_TARGET}"
PAWPAW_TMPDIR="/tmp"

# ---------------------------------------------------------------------------------------------------------------------
# build environment

## build flags

BUILD_FLAGS="-O2 -pipe -I${PAWPAW_PREFIX}/include ${EXTRA_FLAGS}"
BUILD_FLAGS+=" -ffast-math"
BUILD_FLAGS+=" -fPIC -DPIC -DNDEBUG -D_FORTIFY_SOURCE=2"
BUILD_FLAGS+=" -fdata-sections -ffunction-sections -fno-common -fstack-protector -fvisibility=hidden"

if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    BUILD_FLAGS+=" -fno-strict-aliasing -flto"
fi

if [ "${TOOLCHAIN_PREFIX}" = "arm-linux-gnueabihf" ]; then
    BUILD_FLAGS+=" -mfpu=neon-vfpv4 -mfloat-abi=hard"
elif [ "${TOOLCHAIN_PREFIX}" != "aarch64-linux-gnu" ]; then
    BUILD_FLAGS+=" -mtune=generic -msse -msse2"
    if [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
        BUILD_FLAGS+=" -mfpmath=sse"
    fi
fi

if [ "${MACOS}" -eq 1 ]; then
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MAX_ALLOWED=MAC_OS_X_VERSION_10_12 -mmacosx-version-min=10.12 -arch x86_64 -arch arm64"
    else
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MAX_ALLOWED=MAC_OS_X_VERSION_10_8 -mmacosx-version-min=10.8 -stdlib=libc++ -Wno-deprecated-declarations -arch x86_64"
    fi
elif [ "${WIN32}" -eq 1 ]; then
    BUILD_FLAGS+=" -DFLUIDSYNTH_NOT_A_DLL -DPTW32_STATIC_LIB -mstackrealign"
fi

# anything that talks to db should have this
BUILD_FLAGS+=" -DHAVE_MIXED_SIZE_ADDRESSING"

TARGET_CFLAGS="${BUILD_FLAGS}"
TARGET_CXXFLAGS="${BUILD_FLAGS} -fvisibility-inlines-hidden"

## link flags

LINK_FLAGS="-L${PAWPAW_PREFIX}/lib ${BUILD_FLAGS} ${EXTRA_FLAGS}"
LINK_FLAGS+=" -Werror=odr -Werror=lto-type-mismatch"

if [ "${MACOS}" -eq 1 ]; then
    LINK_FLAGS+=" -Wl,-dead_strip -Wl,-dead_strip_dylibs -Wl,-x"

    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        LINK_FLAGS+=" -mmacosx-version-min=10.12 -arch x86_64 -arch arm64"
    else
        LINK_FLAGS+=" -mmacosx-version-min=10.8 -stdlib=libc++ -arch x86_64"
    fi
else
    LINK_FLAGS+=" -Wl,-O1 -Wl,--as-needed -Wl,--gc-sections -Wl,--no-undefined -Wl,--strip-all"
    if [ "${WIN32}" -eq 1 ]; then
        LINK_FLAGS+=" -static -static-libgcc -static-libstdc++ -Wl,-Bstatic"
        if [ "${CROSS_COMPILING}" -eq 0 ] && [ -e "/usr/lib/libssp.a" ]; then
            LINK_FLAGS+=" -lssp"
        else
            LINK_FLAGS+=" -lssp_nonshared"
        fi
    else
        LINK_FLAGS+=" -static-libgcc -static-libstdc++"
    fi
fi

TARGET_LDFLAGS="${LINK_FLAGS}"

## toolchain

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${WIN64}" -eq 1 ]; then
        TOOLCHAIN_PREFIX="x86_64-w64-mingw32"
        TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
    elif [ "${WIN32}" -eq 1 ]; then
        TOOLCHAIN_PREFIX="i686-w64-mingw32"
        TOOLCHAIN_PREFIX_="${TOOLCHAIN_PREFIX}-"
    fi
else
    unset TOOLCHAIN_PREFIX
    unset TOOLCHAIN_PREFIX_
fi

TARGET_AR="${TOOLCHAIN_PREFIX_}ar"
TARGET_CC="${TOOLCHAIN_PREFIX_}gcc"
TARGET_CXX="${TOOLCHAIN_PREFIX_}g++"
TARGET_DLLWRAP="${TOOLCHAIN_PREFIX_}dllwrap"
TARGET_LD="${TOOLCHAIN_PREFIX_}ld"
TARGET_STRIP="${TOOLCHAIN_PREFIX_}strip"
TARGET_WINDRES="${TOOLCHAIN_PREFIX_}windres"
TARGET_PATH="${PAWPAW_PREFIX}/bin:/usr/${TOOLCHAIN_PREFIX}/bin:${PATH}"
TARGET_PKG_CONFIG="${PAWPAW_PREFIX}/bin/pkg-config --static"
TARGET_PKG_CONFIG_PATH="${PAWPAW_PREFIX}/lib/pkgconfig"

# ---------------------------------------------------------------------------------------------------------------------
# other

MAKE_ARGS=""
WAF_ARGS=""
unset EXE_WRAPPER
unset WINEARCH
unset WINEDLLOVERRIDES
unset WINEPREFIX

if which nproc > /dev/null; then
    MAKE_ARGS+="-j $(nproc)"
    WAF_ARGS+="-j $(nproc)"
elif [ "${MACOS}" -eq 1 ]; then
    MAKE_ARGS+="-j $(sysctl -n hw.logicalcpu)"
    WAF_ARGS+="-j $(sysctl -n hw.logicalcpu)"
fi

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    MAKE_ARGS+=" CROSS_COMPILING=true"
    if [ "${WIN32}" -eq 1 ]; then
        export EXE_WRAPPER="wine"
        export WINEARCH="${PAWPAW_TARGET}"
        export WINEDLLOVERRIDES="mscoree,mshtml="
        export WINEPREFIX="${PAWPAW_PREFIX}/wine"
    fi
fi

if [ "${MACOS}" -eq 1 ]; then
    MAKE_ARGS+=" MACOS=true"
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        MAKE_ARGS+=" MACOS_UNIVERSAL=true"
    fi
elif [ "${WIN32}" -eq 1 ]; then
    MAKE_ARGS+=" WINDOWS=true WIN32=true"
    if [ "${WIN64}" -eq 1 ]; then
        MAKE_ARGS+=" WIN64=true"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
