#!/bin/bash

# NOTE `setup/check_target.sh` must be imported before this one

# ---------------------------------------------------------------------------------------------------------------------
# OS setup

if [ "${LINUX}" -eq 1 ]; then
    APP_EXT=""
    CMAKE_SYSTEM_NAME="Linux"
    if [ -n "${LINUX_TARGET}" ]; then
        PAWPAW_TARGET="${LINUX_TARGET}"
    else
        PAWPAW_TARGET="linux"
    fi

elif [ "${MACOS}" -eq 1 ]; then
    APP_EXT=""
    CMAKE_SYSTEM_NAME="Darwin"
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        PAWPAW_TARGET="macos-universal"
    else
        PAWPAW_TARGET="macos"
    fi
    if [ "${MACOS_10_15}" -eq 1 ]; then
        PAWPAW_TARGET+="-10.15"
    fi

elif [ "${WASM}" -eq 1 ]; then
    APP_EXT=".html"
    CMAKE_SYSTEM_NAME="Emscripten"
    PAWPAW_TARGET="wasm"

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

if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    PAWPAW_BUILDDIR+="-lto"
    PAWPAW_PREFIX+="-lto"
fi

if [ -n "${PAWPAW_NOSIMD}" ] && [ "${PAWPAW_NOSIMD}" -eq 1 ]; then
    PAWPAW_BUILDDIR+="-nosimd"
    PAWPAW_PREFIX+="-nosimd"
fi

# ---------------------------------------------------------------------------------------------------------------------
# emscripten setup

if [ "${WASM}" -eq 1 ]; then
    EMSCRIPTEN_VERSION=${EMSCRIPTEN_VERSION:=3.1.27}

    if [ ! -e "${PAWPAW_DIR}/emsdk" ]; then
        git clone https://github.com/emscripten-core/emsdk.git "${PAWPAW_DIR}/emsdk"
        "${PAWPAW_DIR}/emsdk/emsdk" install ${EMSCRIPTEN_VERSION} && "${PAWPAW_DIR}/emsdk/emsdk" activate ${EMSCRIPTEN_VERSION}
    fi

    source "${PAWPAW_DIR}/emsdk/emsdk_env.sh"
fi

# ---------------------------------------------------------------------------------------------------------------------
# build environment

## build flags

BUILD_FLAGS="-Os -pipe -I${PAWPAW_PREFIX}/include ${EXTRA_FLAGS}"
BUILD_FLAGS+=" -ffast-math"
BUILD_FLAGS+=" -fPIC -DPIC -DNDEBUG=1"
BUILD_FLAGS+=" -fdata-sections -ffunction-sections -fno-common -fomit-frame-pointer -fvisibility=hidden"
BUILD_FLAGS+=" -fno-stack-protector -U_FORTIFY_SOURCE -Wp,-U_FORTIFY_SOURCE"

if [ "${GCC}" -eq 1 ]; then
    BUILD_FLAGS+=" -fno-gnu-unique"
fi

if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    BUILD_FLAGS+=" -fno-strict-aliasing -flto"
fi

if [ -z "${PAWPAW_NOSIMD}" ] || [ "${PAWPAW_NOSIMD}" -eq 0 ]; then
    if [ "${WASM}" -eq 1 ]; then
        BUILD_FLAGS+=" -msse -msse2 -msse3 -msimd128"
    elif [ -n "${LINUX_TARGET}" ] && [ "${LINUX_TARGET}" = "linux-armhf" ]; then
        BUILD_FLAGS+=" -mfpu=neon-vfpv4 -mfloat-abi=hard"
    elif [ -n "${LINUX_TARGET}" ] && [ "${LINUX_TARGET}" = "linux-aarch64" ]; then
        # nothing?
        BUILD_FLAGS+=""
    elif [ -n "${LINUX_TARGET}" ] && [ "${LINUX_TARGET}" = "linux-riscv64" ]; then
        # nothing here yet, SIMD is not a thing on RISC-V
        BUILD_FLAGS+=""
    else
        BUILD_FLAGS+=" -mtune=generic -msse -msse2"
        if [ "${MACOS_UNIVERSAL}" -eq 0 ]; then
            BUILD_FLAGS+=" -mfpmath=sse"
        fi
    fi
fi

if [ "${MACOS}" -eq 1 ]; then
    if [ "${MACOS_10_15}" -eq 1 ]; then
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MAX_ALLOWED=MAC_OS_X_VERSION_10_15"
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MIN_REQUIRED=MAC_OS_X_VERSION_10_15"
        BUILD_FLAGS+=" -mmacosx-version-min=10.15"
        export MACOSX_DEPLOYMENT_TARGET="10.15"
    elif [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MAX_ALLOWED=MAC_OS_X_VERSION_10_12"
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MIN_REQUIRED=MAC_OS_X_VERSION_10_12"
        BUILD_FLAGS+=" -mmacosx-version-min=10.12"
        export MACOSX_DEPLOYMENT_TARGET="10.12"
    else
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MAX_ALLOWED=MAC_OS_X_VERSION_10_8"
        BUILD_FLAGS+=" -DMAC_OS_X_VERSION_MIN_REQUIRED=MAC_OS_X_VERSION_10_8"
        BUILD_FLAGS+=" -mmacosx-version-min=10.8"
        BUILD_FLAGS+=" -stdlib=libc++"
        BUILD_FLAGS+=" -Wno-deprecated-declarations"
        export MACOSX_DEPLOYMENT_TARGET="10.8"
    fi
    if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
        BUILD_FLAGS+=" -arch x86_64 -arch arm64"
    else
        BUILD_FLAGS+=" -arch x86_64"
    fi
    BUILD_FLAGS+=" -Werror=objc-method-access"
elif [ "${WIN32}" -eq 1 ]; then
    BUILD_FLAGS+=" -DPTW32_STATIC_LIB"
    BUILD_FLAGS+=" -D__STDC_FORMAT_MACROS=1"
    BUILD_FLAGS+=" -D__USE_MINGW_ANSI_STDIO=1"
    BUILD_FLAGS+=" -mstackrealign"
    BUILD_FLAGS+=" -posix"
fi

# anything that talks to db should have this
BUILD_FLAGS+=" -DHAVE_MIXED_SIZE_ADDRESSING"

TARGET_CFLAGS="${BUILD_FLAGS}"
TARGET_CXXFLAGS="${BUILD_FLAGS} -fvisibility-inlines-hidden"

## link flags

LINK_FLAGS="-L${PAWPAW_PREFIX}/lib ${BUILD_FLAGS} ${EXTRA_FLAGS}"

if [ -z "${PAWPAW_SKIP_LTO}" ] || [ "${PAWPAW_SKIP_LTO}" -eq 0 ]; then
    LINK_FLAGS+=" -Werror=odr"
    if [ "${GCC}" -eq 1 ]; then
        LINK_FLAGS+=" -Werror=lto-type-mismatch"
    fi
fi

if [ "${MACOS}" -eq 1 ]; then
    if [ -z "${PAWPAW_SKIP_STRIPPING}" ] || [ "${PAWPAW_SKIP_STRIPPING}" -eq 0 ]; then
        LINK_FLAGS+=" -Wl,-dead_strip,-dead_strip_dylibs,-x"
    fi
elif [ "${WASM}" -eq 1 ]; then
    LINK_FLAGS+=" -Wl,--gc-sections"
    LINK_FLAGS+=" -sENVIRONMENT=web"
    LINK_FLAGS+=" -sLLD_REPORT_UNDEFINED"
    if [ -z "${PAWPAW_SKIP_STRIPPING}" ] || [ "${PAWPAW_SKIP_STRIPPING}" -eq 0 ]; then
        LINK_FLAGS+=" -sAGGRESSIVE_VARIABLE_ELIMINATION=1"
    fi
else
    LINK_FLAGS+=" -Wl,-O1,--gc-sections,--no-undefined"
    if [ -z "${PAWPAW_SKIP_STRIPPING}" ] || [ "${PAWPAW_SKIP_STRIPPING}" -eq 0 ]; then
        LINK_FLAGS+=" -Wl,--as-needed,--strip-all"
    fi
    if [ "${WIN32}" -eq 1 ]; then
        LINK_FLAGS+=" -static -static-libgcc -static-libstdc++ -Wl,-Bstatic"
    else
        LINK_FLAGS+=" -static-libgcc -static-libstdc++"
    fi
fi

TARGET_LDFLAGS="${LINK_FLAGS}"

## toolchain

TARGET_AR="${TOOLCHAIN_PREFIX_}ar"
TARGET_CC="${TOOLCHAIN_PREFIX_}gcc"
TARGET_CXX="${TOOLCHAIN_PREFIX_}g++"
TARGET_DLLWRAP="${TOOLCHAIN_PREFIX_}dllwrap"
TARGET_LD="${TOOLCHAIN_PREFIX_}ld"
TARGET_NM="${TOOLCHAIN_PREFIX_}nm"
TARGET_RANLIB="${TOOLCHAIN_PREFIX_}ranlib"
TARGET_STRIP="${TOOLCHAIN_PREFIX_}strip"
TARGET_WINDRES="${TOOLCHAIN_PREFIX_}windres"
TARGET_PATH="${PAWPAW_PREFIX}/bin:/usr/${TOOLCHAIN_PREFIX}/bin:${PATH}"
TARGET_PKG_CONFIG="${PAWPAW_PREFIX}/bin/pkg-config --static"
TARGET_PKG_CONFIG_PATH="${PAWPAW_PREFIX}/lib/pkgconfig"

if [ "${WASM}" -eq 1 ]; then
    TARGET_AR="emar"
    TARGET_CC="emcc"
    TARGET_CXX="em++"
    TARGET_NM="emnm"
    TARGET_RANLIB="emranlib"
    TARGET_STRIP="emstrip"
fi

if [ -n "${PAWPAW_SKIP_STRIPPING}" ] && [ "${PAWPAW_SKIP_STRIPPING}" -eq 1 ]; then
    TARGET_STRIP="true"
fi

# ---------------------------------------------------------------------------------------------------------------------
# find needed programs

autoconf=$(command -v autoconf || true)
cmake=$(command -v cmake || true)
jq=$(command -v jq || true)
meson=$(command -v meson || true)
ninja=$(command -v ninja || true)

if [ -z "${autoconf}" ] && [ -e "/opt/homebrew/bin/autoconf" ]; then
    autoconf="/opt/homebrew/bin/autoconf"
fi

if [ -z "${cmake}" ] && [ -e "/opt/homebrew/bin/cmake" ]; then
    cmake="/opt/homebrew/bin/cmake"
fi

if [ -z "${jq}" ] && [ -e "/opt/homebrew/bin/jq" ]; then
    jq="/opt/homebrew/bin/jq"
fi

if [ -z "${meson}" ] && [ -e "/opt/homebrew/bin/meson" ]; then
    meson="/opt/homebrew/bin/meson"
fi

if [ -z "${ninja}" ] && [ -e "/opt/homebrew/bin/ninja" ]; then
    ninja="/opt/homebrew/bin/ninja"
fi

# ---------------------------------------------------------------------------------------------------------------------
# other

MAKE_ARGS=""
WAF_ARGS=""

unset WINEARCH
unset WINEDLLOVERRIDES
unset WINEPREFIX

if [ "${MACOS}" -eq 1 ]; then
    MAKE_ARGS+="-j $(sysctl -n hw.logicalcpu)"
    WAF_ARGS+="-j $(sysctl -n hw.logicalcpu)"
elif which nproc > /dev/null; then
    MAKE_ARGS+="-j $(nproc)"
    WAF_ARGS+="-j $(nproc)"
fi

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    MAKE_ARGS+=" CROSS_COMPILING=true"
    if [ "${EXE_WRAPPER}" = "wine" ]; then
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
