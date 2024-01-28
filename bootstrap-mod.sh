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

export PAWPAW_FAST_MATH=1
export PAWPAW_MODAUDIO=1

./bootstrap-common.sh "${target}"
./bootstrap-jack2.sh "${target}"
./bootstrap-plugins.sh "${target}"
./bootstrap-python.sh "${target}"

if [ -z "${PAWPAW_SKIP_QT}" ]; then
    ./bootstrap-qt.sh "${target}"
fi

# ---------------------------------------------------------------------------------------------------------------------
# source setup code

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------
# armadillo

ARMADILLO_VERSION="12.6.5"
ARMADILLO_URL="http://download.sourceforge.net/arma"

download armadillo "${ARMADILLO_VERSION}" "${ARMADILLO_URL}" "tar.xz"
build_cmake armadillo "${ARMADILLO_VERSION}" "${ARMADILLO_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# hylia

HYLIA_VERSION="6421909123974ffd431ace47589975f5929bc746"
HYLIA_URL="https://github.com/falkTX/hylia.git"

HYLIA_EXTRAFLAGS="NOOPT=true"

download hylia "${HYLIA_VERSION}" "${HYLIA_URL}" "" "git"
build_make hylia "${HYLIA_VERSION}" "${HYLIA_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------
# jack2

JACK2_VERSION="806da09a120f254ae231c2ef87cf9fe2f4fb4f5b"
JACK2_URL="https://github.com/jackaudio/jack2.git"

JACK2_EXTRAFLAGS=""
JACK2_EXTRAFLAGS+=" --autostart=none"
JACK2_EXTRAFLAGS+=" --classic"
JACK2_EXTRAFLAGS+=" --db=no"
JACK2_EXTRAFLAGS+=" --doxygen=no"
JACK2_EXTRAFLAGS+=" --firewire=no"
JACK2_EXTRAFLAGS+=" --iio=no"
JACK2_EXTRAFLAGS+=" --celt=no"
JACK2_EXTRAFLAGS+=" --opus=no"
JACK2_EXTRAFLAGS+=" --samplerate=no"
JACK2_EXTRAFLAGS+=" --systemd=no"

if [ "${LINUX}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --platform=linux --portaudio=yes --alsa=yes --libdbus=yes"
elif [ "${MACOS}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --platform=darwin"
elif [ "${WIN32}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --platform=win32"
fi

if [ "${WIN32}" -eq 1 ]; then
    JACK2_EXTRAFLAGS+=" --static"
fi

if [ "${LINUX}" -eq 1 ]; then
    export EXTRA_LDFLAGS='-Wl,-rpath,$ORIGIN -Wl,-rpath,$ORIGIN/.. -Wl,-rpath,$ORIGIN/../lib'
fi

download jack2 "${JACK2_VERSION}" "${JACK2_URL}" "" "git"
patch_file jack2 "${JACK2_VERSION}" "dbus/audio_reserve.c" "s/Jack audio server/MOD Desktop App/"
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
# juce-6.0

JUCE_6_0_VERSION="24b7e3b2b2c4713d53163b58aed8f79a605218e9"
JUCE_6_0_URL="https://github.com/DISTRHO/JUCE.git"

JUCE_6_0_EXTRAFLAGS=""
JUCE_6_0_EXTRAFLAGS+=" -DCMAKE_INSTALL_PREFIX=${PAWPAW_PREFIX}"
JUCE_6_0_EXTRAFLAGS+=" -DJUCE_BUILD_HELPER_TOOLS=ON"
JUCE_6_0_EXTRAFLAGS+=" -DJUCE_INSTALL_DESTINATION=lib/cmake/JUCE-6.0.8"

download juce-6.0 "${JUCE_6_0_VERSION}" "${JUCE_6_0_URL}" "" "git"
build_host_cmake juce-6.0 "${JUCE_6_0_VERSION}" "${JUCE_6_0_EXTRAFLAGS}"

link_target_file juce-6.0 "${JUCE_6_0_VERSION}" "JUCEConfig.cmake" "lib/cmake/JUCE-6.0.8/JUCE-6.0.8Config.cmake"
install_file juce-6.0 "${JUCE_6_0_VERSION}" "build/extras/Build/juceaide/juceaide_artefacts/Release/juceaide" "bin" "juceaide60"
install_file juce-6.0 "${JUCE_6_0_VERSION}" "extras/Build/CMake/lv2_ttl_generator.c" "lib/cmake/JUCE-6.0.8"

# ---------------------------------------------------------------------------------------------------------------------
# juce-6.1

JUCE_6_1_VERSION="2cf0224df33e52ebbaebacc9a846d2be26cdcbcb"
JUCE_6_1_URL="https://github.com/DISTRHO/JUCE.git"

JUCE_6_1_EXTRAFLAGS=""
JUCE_6_1_EXTRAFLAGS+=" -DCMAKE_INSTALL_PREFIX=${PAWPAW_PREFIX}"
JUCE_6_1_EXTRAFLAGS+=" -DJUCE_BUILD_HELPER_TOOLS=ON"
JUCE_6_1_EXTRAFLAGS+=" -DJUCE_INSTALL_DESTINATION=lib/cmake/JUCE-6.1.6"

download juce-6.1 "${JUCE_6_1_VERSION}" "${JUCE_6_1_URL}" "" "git"
build_host_cmake juce-6.1 "${JUCE_6_1_VERSION}" "${JUCE_6_1_EXTRAFLAGS}"

link_target_file juce-6.1 "${JUCE_6_1_VERSION}" "JUCEConfig.cmake" "lib/cmake/JUCE-6.1.6/JUCE-6.1.6Config.cmake"
install_file juce-6.1 "${JUCE_6_1_VERSION}" "build/extras/Build/juceaide/juceaide_artefacts/Release/juceaide" "bin" "juceaide61"
install_file juce-6.1 "${JUCE_6_1_VERSION}" "extras/Build/CMake/lv2_ttl_generator.c" "lib/cmake/JUCE-6.1.6"

# ---------------------------------------------------------------------------------------------------------------------
# juce-7.0

JUCE_7_0_VERSION="c3099e733e90b8a2e7071698980abd70efb9a4e7"
JUCE_7_0_URL="https://github.com/DISTRHO/JUCE.git"

JUCE_7_0_EXTRAFLAGS=""
JUCE_7_0_EXTRAFLAGS+=" -DCMAKE_INSTALL_PREFIX=${PAWPAW_PREFIX}"
JUCE_7_0_EXTRAFLAGS+=" -DJUCE_BUILD_HELPER_TOOLS=ON"
JUCE_7_0_EXTRAFLAGS+=" -DJUCE_INSTALL_DESTINATION=lib/cmake/JUCE-7.0.9"

download juce-7.0 "${JUCE_7_0_VERSION}" "${JUCE_7_0_URL}" "" "git"
build_host_cmake juce-7.0 "${JUCE_7_0_VERSION}" "${JUCE_7_0_EXTRAFLAGS}"

link_target_file juce-7.0 "${JUCE_7_0_VERSION}" "JUCEConfig.cmake" "lib/cmake/JUCE-7.0.9/JUCE-7.0.9Config.cmake"
install_file juce-7.0 "${JUCE_7_0_VERSION}" "build/extras/Build/juceaide/juceaide_artefacts/Release/juceaide" "bin" "juceaide70"

# ---------------------------------------------------------------------------------------------------------------------
# lvtk1

LVTK1_VERSION="c105fd5077b4f7d963ad543b9979b94b9b052551"
LVTK1_URL="https://github.com/lvtk/lvtk.git"

LVTK1_EXTRAFLAGS=""
LVTK1_EXTRAFLAGS+=" --disable-examples"
LVTK1_EXTRAFLAGS+=" --disable-tools"
LVTK1_EXTRAFLAGS+=" --disable-ui"

download lvtk1 "${LVTK1_VERSION}" "${LVTK1_URL}" "" "git"

# force waf update for py3 compat
if [ ! -e "${PAWPAW_BUILDDIR}/lvtk1-${LVTK1_VERSION}/.stamp_configured" ]; then
    cp -v "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}/waf" "${PAWPAW_BUILDDIR}/lvtk1-${LVTK1_VERSION}/"
    cp -rv "${PAWPAW_BUILDDIR}/jack2-${JACK2_VERSION}/waflib" "${PAWPAW_BUILDDIR}/lvtk1-${LVTK1_VERSION}/"
fi

build_waf lvtk1 "${LVTK1_VERSION}" "${LVTK1_EXTRAFLAGS}"

# ---------------------------------------------------------------------------------------------------------------------

if [ -n "${PAWPAW_SKIP_PYTHON_MODULES}" ] && [ "${PAWPAW_SKIP_PYTHON_MODULES}" -eq 1 ]; then
    exit 0
fi

# ---------------------------------------------------------------------------------------------------------------------
# aggdraw

AGGDRAW_VERSION="1.3.11"

export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 freetype2 libpng)"
export EXTRA_LDFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 freetype2 libpng) -shared"
if [ "${MACOS}" -eq 1 ]; then
    export EXTRA_LDFLAGS+=" -Wl,-undefined,dynamic_lookup"
elif [ "${WIN32}" -eq 1 ]; then
    export EXTRA_LDFLAGS+=" -lgdi32 -lkernel32 -luser32"
fi

export AGGDRAW_FREETYPE_ROOT="${PAWPAW_PREFIX}"
export LDSHARED="${TARGET_CXX}"

download aggdraw "${AGGDRAW_VERSION}" "https://files.pythonhosted.org/packages/ef/29/fddf555c68920bb0aff977425af786226db2a78379e706951ff32b4492ef"
build_python aggdraw "${AGGDRAW_VERSION}"

unset AGGDRAW_FREETYPE_ROOT
unset LDSHARED

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/aggdraw.py" ]; then
        ln -sv "${PYTHONPATH}"/aggdraw-*.egg/aggdraw.py "${PYTHONPATH}/aggdraw.py"
    fi
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

export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 freetype2 libpng)"
export EXTRA_LDFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 freetype2 libpng) -shared"
if [ "${MACOS}" -eq 1 ]; then
    export EXTRA_LDFLAGS+=" -Wl,-undefined,dynamic_lookup"
elif [ "${WIN32}" -eq 1 ]; then
    export EXTRA_LDFLAGS+=" -lgdi32 -lkernel32 -lpsapi -luser32"
fi

export LDSHARED="${TARGET_CXX}"

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

unset LDSHARED

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/PIL" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL "${PYTHONPATH}/PIL"
    fi
    if [ ! -e "${PYTHONPATH}/PIL/_imaging.pyd" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL/_imaging.*.so "${PYTHONPATH}/PIL/_imaging.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/PIL/_imagingft.pyd" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL/_imagingft.*.so "${PYTHONPATH}/PIL/_imagingft.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/PIL/_imagingmath.pyd" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL/_imagingmath.*.so "${PYTHONPATH}/PIL/_imagingmath.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/PIL/_imagingmorph.pyd" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL/_imagingmorph.*.so "${PYTHONPATH}/PIL/_imagingmorph.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/PIL/_imagingtk.pyd" ]; then
        ln -sv "${PYTHONPATH}"/Pillow-*.egg/PIL/_imagingtk.*.so "${PYTHONPATH}/PIL/_imagingtk.pyd"
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
# cryptodome

CRYPTODOME_VERSION="3.19.0"

export EXTRA_CFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --cflags python3 openssl)"
export EXTRA_LDFLAGS="$(${PAWPAW_PREFIX}/bin/pkg-config --libs python3 openssl) -shared"
export LDSHARED="${TARGET_CXX}"

download pycryptodomex "${CRYPTODOME_VERSION}" "https://files.pythonhosted.org/packages/14/c9/09d5df04c9f29ae1b49d0e34c9934646b53bb2131a55e8ed2a0d447c7c53"
build_python pycryptodomex "${CRYPTODOME_VERSION}"

if [ "${WIN32}" -eq 1 ] && [ "${CROSS_COMPILING}" -eq 1 ]; then
    PYTHONPATH="${PAWPAW_PREFIX}/lib/python3.8/site-packages"
    if [ ! -e "${PYTHONPATH}/Cryptodome" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome "${PYTHONPATH}/Cryptodome"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_ARC4.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_ARC4.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_ARC4.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_chacha20.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_chacha20.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_chacha20.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_pkcs1_decode.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_pkcs1_decode.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_pkcs1_decode.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_aes.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_aes.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_aes.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_aesni.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_aesni.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_aesni.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_arc2.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_arc2.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_arc2.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_blowfish.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_blowfish.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_blowfish.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_cast.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_cast.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_cast.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_cbc.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_cbc.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_cbc.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_cfb.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_cfb.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_cfb.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_ctr.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_ctr.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_ctr.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_des3.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_des3.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_des3.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_des.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_des.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_des.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_ecb.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_ecb.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_ecb.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_eksblowfish.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_eksblowfish.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_eksblowfish.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_ocb.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_ocb.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_ocb.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_raw_ofb.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_raw_ofb.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_raw_ofb.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Cipher/_Salsa20.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Cipher/_Salsa20.abi3.so "${PYTHONPATH}/Cryptodome/Cipher/_Salsa20.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_BLAKE2b.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_BLAKE2b.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_BLAKE2b.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_BLAKE2s.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_BLAKE2s.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_BLAKE2s.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_ghash_clmul.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_ghash_clmul.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_ghash_clmul.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_ghash_portable.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_ghash_portable.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_ghash_portable.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_keccak.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_keccak.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_keccak.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_MD2.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_MD2.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_MD2.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_MD4.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_MD4.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_MD4.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_MD5.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_MD5.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_MD5.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_poly1305.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_poly1305.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_poly1305.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_RIPEMD160.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_RIPEMD160.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_RIPEMD160.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_SHA1.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_SHA1.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_SHA1.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_SHA224.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_SHA224.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_SHA224.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_SHA256.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_SHA256.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_SHA256.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_SHA384.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_SHA384.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_SHA384.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Hash/_SHA512.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Hash/_SHA512.abi3.so "${PYTHONPATH}/Cryptodome/Hash/_SHA512.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Math/_modexp.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Math/_modexp.abi3.so "${PYTHONPATH}/Cryptodome/Math/_modexp.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Protocol/_scrypt.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Protocol/_scrypt.abi3.so "${PYTHONPATH}/Cryptodome/Protocol/_scrypt.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/PublicKey/_ec_ws.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/PublicKey/_ec_ws.abi3.so "${PYTHONPATH}/Cryptodome/PublicKey/_ec_ws.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/PublicKey/_ed25519.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/PublicKey/_ed25519.abi3.so "${PYTHONPATH}/Cryptodome/PublicKey/_ed25519.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/PublicKey/_ed448.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/PublicKey/_ed448.abi3.so "${PYTHONPATH}/Cryptodome/PublicKey/_ed448.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/PublicKey/_x25519.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/PublicKey/_x25519.abi3.so "${PYTHONPATH}/Cryptodome/PublicKey/_x25519.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Util/_cpuid_c.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Util/_cpuid_c.abi3.so "${PYTHONPATH}/Cryptodome/Util/_cpuid_c.pyd"
    fi
    if [ ! -e "${PYTHONPATH}/Cryptodome/Util/_strxor.pyd" ]; then
        ln -sv "${PYTHONPATH}"/pycryptodomex-*.egg/Cryptodome/Util/_strxor.abi3.so "${PYTHONPATH}/Cryptodome/Util/_strxor.pyd"
    fi
    unset PYTHONPATH
fi

# ---------------------------------------------------------------------------------------------------------------------
