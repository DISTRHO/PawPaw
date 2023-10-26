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
# LTO is unwanted for MOD builds, make sure it is off

export PAWPAW_SKIP_LTO=1

# ---------------------------------------------------------------------------------------------------------------------
# run bootstrap dependencies

./bootstrap-common.sh "${target}"
./bootstrap-jack2.sh "${target}"
./bootstrap-plugins.sh "${target}"
./bootstrap-python.sh "${target}"

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# Use local Qt on Linux builds
if [ "${LINUX}" -eq 1 ]; then
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
    if ! pkg-config --exists Qt5Core Qt5Gui Qt5Svg Qt5Widgets; then
        echo "Qt system libs are not available, cannot continue"
        exit 2
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Core.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Core)/Qt5Core.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Core.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Gui.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Gui)/Qt5Gui.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Gui.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Svg.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Svg)/Qt5Svg.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Svg.pc
    fi
    if [ ! -e "${TARGET_PKG_CONFIG_PATH}/Qt5Widgets.pc" ]; then
        cp $(pkg-config --variable=pcfiledir Qt5Widgets)/Qt5Widgets.pc ${TARGET_PKG_CONFIG_PATH}/
        sed -i '/Libs.private/d' ${TARGET_PKG_CONFIG_PATH}/Qt5Widgets.pc
    fi
else
    ./bootstrap-qt.sh "${target}"
fi

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
    if [ ! -e "${PAWPAW_PREFIX}-host/bin/awk" ]; then
        ln -s $(command -v gawk) "${PAWPAW_PREFIX}-host/bin/awk"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/cp" ]; then
        ln -s $(command -v gcp) "${PAWPAW_PREFIX}-host/bin/cp"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/install" ]; then
        ln -s $(command -v ginstall) "${PAWPAW_PREFIX}-host/bin/install"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/libtool" ]; then
        ln -s $(command -v glibtool) "${PAWPAW_PREFIX}-host/bin/libtool"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/libtoolize" ]; then
        ln -s $(command -v glibtoolize) "${PAWPAW_PREFIX}-host/bin/libtoolize"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/m4" ]; then
        ln -s $(command -v gm4) "${PAWPAW_PREFIX}-host/bin/m4"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/make" ]; then
        ln -s $(command -v gmake) "${PAWPAW_PREFIX}-host/bin/make"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/readlink" ]; then
        ln -s $(command -v greadlink) "${PAWPAW_PREFIX}-host/bin/readlink"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/realpath" ]; then
        ln -s $(command -v grealpath) "${PAWPAW_PREFIX}-host/bin/realpath"
    fi

    if [ ! -e "${PAWPAW_PREFIX}-host/bin/sed" ]; then
        ln -s $(command -v gsed) "${PAWPAW_PREFIX}-host/bin/sed"
    fi
fi

# ---------------------------------------------------------------------------------------------------------------------
# lvtk1

# LVTK1_VERSION="c105fd5077b4f7d963ad543b9979b94b9b052551"
# LVTK1_URL="https://github.com/lvtk/lvtk.git"
# 
# LVTK1_EXTRAFLAGS=""
# LVTK1_EXTRAFLAGS+=" --disable-examples"
# LVTK1_EXTRAFLAGS+=" --disable-tools"
# LVTK1_EXTRAFLAGS+=" --disable-ui"
# 
# download lvtk1 "${LVTK1_VERSION}" "${LVTK1_URL}" "" "git"
# build_waf lvtk1 "${LVTK1_VERSION}" "${LVTK1_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# jack2

JACK2_VERSION="250420381b1a6974798939ad7104ab1a4b9a9994"
JACK2_URL="https://github.com/jackaudio/jack2.git"

JACK2_EXTRAFLAGS=""
JACK2_EXTRAFLAGS+=" --autostart=none"
JACK2_EXTRAFLAGS+=" --classic"
JACK2_EXTRAFLAGS+=" --db=yes"
JACK2_EXTRAFLAGS+=" --doxygen=no"
JACK2_EXTRAFLAGS+=" --firewire=no"
JACK2_EXTRAFLAGS+=" --iio=no"
JACK2_EXTRAFLAGS+=" --celt=no"
JACK2_EXTRAFLAGS+=" --opus=no"
JACK2_EXTRAFLAGS+=" --samplerate=no"
JACK2_EXTRAFLAGS+=" --systemd=no"

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    if [ "${LINUX}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=linux --portaudio=yes --alsa=yes"
    elif [ "${MACOS}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=darwin"
    elif [ "${WIN32}" -eq 1 ]; then
        JACK2_EXTRAFLAGS+=" --platform=win32"
    fi
fi

if [ "${WIN32}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --static"
fi

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
# jack-example-tools

JACK_EXAMPLE_TOOLS_VERSION="7cf014d3b3b75ad88a0785957b0f2cffad243b6b"
JACK_EXAMPLE_TOOLS_URL="https://github.com/jackaudio/jack-example-tools.git"

JACK_EXAMPLE_TOOLS_EXTRAFLAGS=""
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Dalsa_in_out=disabled"
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Djack_net=disabled"
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Djack_netsource=disabled"
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Djack_rec=disabled"
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Dopus_support=disabled"
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Dreadline_support=disabled"
JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Dzalsa=disabled"

if [ "${LINUX}" -eq 1 ]; then
    JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Dalsa_midi=enabled"
else
    JACK_EXAMPLE_TOOLS_EXTRAFLAGS+=" -Dalsa_midi=disabled"
fi

download jack-example-tools "${JACK_EXAMPLE_TOOLS_VERSION}" "${JACK_EXAMPLE_TOOLS_URL}" "" "git"
build_meson jack-example-tools "${JACK_EXAMPLE_TOOLS_VERSION}" "${JACK_EXAMPLE_TOOLS_EXTRAFLAGS}"

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
# setuptools

SETUPTOOLS_VERSION="68.2.2"

download setuptools "${SETUPTOOLS_VERSION}" "https://files.pythonhosted.org/packages/ef/cc/93f7213b2ab5ed383f98ce8020e632ef256b406b8569606c3f160ed8e1c9"
build_python setuptools "${SETUPTOOLS_VERSION}"

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/_distutils_hack" ]; then
        ln -sv "${PYTHONPATH}"/setuptools-*.egg/_distutils_hack "${PYTHONPATH}/_distutils_hack"
    fi
    if [ ! -e "${PYTHONPATH}/pkg_resources" ]; then
        ln -sv "${PYTHONPATH}"/setuptools-*.egg/pkg_resources "${PYTHONPATH}/pkg_resources"
    fi
    if [ ! -e "${PYTHONPATH}/setuptools" ]; then
        ln -sv "${PYTHONPATH}"/setuptools-*.egg/setuptools "${PYTHONPATH}/setuptools"
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

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PILLOW_EXTRAFLAGS+=" --disable-platform-guessing"
fi

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
