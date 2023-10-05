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

export PAWPAW_SKIP_LTO=1
source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependencies

./bootstrap-common.sh "${target}"
./bootstrap-jack2.sh "${target}"
./bootstrap-plugins.sh "${target}"
./bootstrap-python.sh "${target}"
./bootstrap-qt.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# merged usr mode

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

mkdir -p "${PAWPAW_PREFIX}-host/usr"

if [ ! -e "${PAWPAW_PREFIX}-host/usr/bin" ]; then
    ln -s ../bin "${PAWPAW_PREFIX}-host/usr/bin"
fi

# ---------------------------------------------------------------------------------------------------------------------
# jack2

JACK2_EXTRAFLAGS=""

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${LINUX}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=linux"
    elif [ "${MACOS}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=darwin"
    elif [ "${WIN32}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=win32"
    fi
fi

if [ "${WIN32}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --static"
fi

JACK2_VERSION="250420381b1a6974798939ad7104ab1a4b9a9994"
JACK2_URL="https://github.com/jackaudio/jack2.git"

download jack2 "${JACK2_VERSION}" "${JACK2_URL}" "" "git"
build_waf jack2 "${JACK2_VERSION}" "${JACK2_EXTRAFLAGS}"

# patch pkg-config file for static win32 builds
if [ "${WIN32}" -eq 1 ]; then
    if [ "${WIN64}" -eq 1 ]; then
        s="64"
    else
        s=""
    fi
    sed -i -e "s/-L\${libdir} -ljack${s}/-L\${libdir} -Wl,-Bdynamic -ljackserver${s} -Wl,-Bstatic/" "${PAWPAW_PREFIX}/lib/pkgconfig/jack.pc"
fi

# ---------------------------------------------------------------------------------------------------------------------
# hylia

HYLIA_VERSION="6421909123974ffd431ace47589975f5929bc746"
HYLIA_URL="https://github.com/falkTX/hylia.git"

HYLIA_EXTRAFLAGS="NOOPT=true"

download hylia "${HYLIA_VERSION}" "${HYLIA_URL}" "" "git"
build_make hylia "${HYLIA_VERSION}" "${HYLIA_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# aggdraw

AGGDRAW_VERSION="1.3.11"

if [ "${WIN32}" -eq 1 ]; then
    export AGGDRAW_FREETYPE_ROOT="${PAWPAW_PREFIX}"
    export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 freetype2 libpng)"
    export EXTRA_LDFLAGS="-shared $(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 freetype2 libpng) -lgdi32 -lkernel32 -luser32"
    export LDSHARED="${TARGET_CXX}"
fi

download aggdraw "${AGGDRAW_VERSION}" "https://files.pythonhosted.org/packages/ef/29/fddf555c68920bb0aff977425af786226db2a78379e706951ff32b4492ef"
build_python aggdraw "${AGGDRAW_VERSION}"

if [ "${WIN32}" -eq 1 ]; then
    unset AGGDRAW_FREETYPE_ROOT
    unset LDSHARED
fi

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/aggdraw.pyd" ]; then
        ln -sv "${PYTHONPATH}"/aggdraw-*.egg/*.so "${PYTHONPATH}/aggdraw.pyd"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
# Pillow

PILLOW_VERSION="8.2.0"

if [ "${WIN32}" -eq 1 ]; then
    export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 freetype2 libpng)"
    export EXTRA_LDFLAGS="-shared $(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 freetype2 libpng) -lgdi32 -lkernel32 -lpsapi -luser32"
    export LDSHARED="${TARGET_CXX}"
fi

PILLOW_EXTRAFLAGS=""
PILLOW_EXTRAFLAGS+=" --enable-freetype"
PILLOW_EXTRAFLAGS+=" --enable-zlib"
PILLOW_EXTRAFLAGS+=" --disable-imagequant"
PILLOW_EXTRAFLAGS+=" --disable-jpeg"
PILLOW_EXTRAFLAGS+=" --disable-jpeg2000"
PILLOW_EXTRAFLAGS+=" --disable-tiff"
PILLOW_EXTRAFLAGS+=" --disable-webp"
PILLOW_EXTRAFLAGS+=" --disable-webpmux"
PILLOW_EXTRAFLAGS+=" --disable-xcb"
PILLOW_EXTRAFLAGS+=" --disable-platform-guessing"

download Pillow "${PILLOW_VERSION}" "https://files.pythonhosted.org/packages/21/23/af6bac2a601be6670064a817273d4190b79df6f74d8012926a39bc7aa77f"
build_python Pillow "${PILLOW_VERSION}" "${PILLOW_EXTRAFLAGS}"

if [ "${WIN32}" -eq 1 ]; then
    unset LDSHARED
fi

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/PIL" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL "${PYTHONPATH}/PIL"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
# setuptools

SETUPTOOLS_VERSION="68.2.2"

download setuptools "${SETUPTOOLS_VERSION}" "https://files.pythonhosted.org/packages/ef/cc/93f7213b2ab5ed383f98ce8020e632ef256b406b8569606c3f160ed8e1c9"
build_python setuptools "${SETUPTOOLS_VERSION}"

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/pkg_resources" ]; then
        ln -sv "${PYTHONPATH}"/setuptools-*.egg/pkg_resources "${PYTHONPATH}/pkg_resources"
    fi
    if [ ! -e "${PYTHONPATH}/setuptools" ]; then
        ln -sv "${PYTHONPATH}"/setuptools-*.egg/setuptools "${PYTHONPATH}/setuptools"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
# tornado

TORNADO_VERSION="4.3"

download tornado "${TORNADO_VERSION}" "https://files.pythonhosted.org/packages/21/29/e64c97013e97d42d93b3d5997234a6f17455f3744847a7c16289289f8fa6"
build_python tornado "${TORNADO_VERSION}"

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/tornado" ]; then
        ln -sv "${PYTHONPATH}"/tornado-*.egg/tornado "${PYTHONPATH}/tornado"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
