#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------
# common URLs

DROBILLA_URL=https://download.drobilla.net/
XIPH_URL=https://downloads.xiph.org/releases

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap base

PKG_CONFIG_VERSION=0.28
PKG_CONFIG_URL=https://pkg-config.freedesktop.org/releases

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap common

LIBOGG_VERSION=1.3.5
LIBOGG_URL=${XIPH_URL}/ogg

LIBVORBIS_VERSION=1.3.7
LIBVORBIS_URL=${XIPH_URL}/vorbis

FLAC_VERSION=1.4.0
FLAC_URL=${XIPH_URL}/flac

OPUS_VERSION=1.3.1
OPUS_URL=${XIPH_URL}/opus

LIBSNDFILE_VERSION=1.1.0
LIBSNDFILE_URL=https://github.com/libsndfile/libsndfile/releases/download/${LIBSNDFILE_VERSION}

LIBSAMPLERATE_VERSION=0.1.9
LIBSAMPLERATE_URL=http://www.mega-nerd.com/SRC

ZLIB_VERSION=cacf7f1d4e3d44d871b605da3b647f07d718623f # 1.2.11
ZLIB_URL=https://github.com/madler/zlib.git

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap plugins

FFTW_VERSION=3.3.10
FFTW_URL=http://www.fftw.org

PCRE_VERSION=8.45
PCRE_URL=http://download.sourceforge.net/pcre

if [ "${WIN32}" -eq 1 ]; then
    LIBFFI_VERSION=3.4.2
    GLIB_MVERSION=2.45
    GLIB_VERSION=2.45.8
    GLIB_TAR_EXT=tar.xz
else
    LIBFFI_VERSION=3.3
    # LIBFFI_URL=https://sourceware.org/pub/libffi
    GLIB_MVERSION=2.22
    GLIB_VERSION=2.22.5
    GLIB_TAR_EXT=tar.gz
fi

LIBFFI_URL=https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}
GLIB_URL=https://download.gnome.org/sources/glib/${GLIB_MVERSION}

LIBLO_VERSION=0.31
LIBLO_URL=http://download.sourceforge.net/liblo

LV2_VERSION=0bcde338db1c63bbc503b4d1f6d7b55ed43154af # 1.18.10
LV2_URL=https://gitlab.com/lv2/lv2.git

SERD_VERSION=0.30.16
SERD_URL=${DROBILLA_URL}

SORD_VERSION=0.16.14
SORD_URL=${DROBILLA_URL}

SRATOM_VERSION=0.6.14
SRATOM_URL=${DROBILLA_URL}

LILV_VERSION=0.24.20
LILV_URL=${DROBILLA_URL}

LV2LINT_VERSION=0.16.2
LV2LINT_URL=https://gitlab.com/OpenMusicKontrollers/lv2lint/-/archive/${LV2LINT_VERSION}

KXSTUDIO_LV2_EXTENSIONS_VERSION=58010323797754dc6cd50084d456e5ac2e7c034c
KXSTUDIO_LV2_EXTENSIONS_URL=https://github.com/KXStudio/LV2-Extensions.git

MOD_SDK_VERSION=60abe7176b4e4f46f20a41cdf3d65d909c8d8a34
MOD_SDK_URL=https://github.com/moddevices/mod-lv2-extensions.git

FLUIDSYNTH_VERSION=f65c6ba25fb2c7e37c89fc6a4afc5aa645e208c2 # 1.1.11
FLUIDSYNTH_URL=https://github.com/FluidSynth/fluidsynth.git

MXML_VERSION=38b044ed8ca2a611ed9ed3e26c4b46416335194e # 3.2
MXML_URL=https://github.com/michaelrsweet/mxml.git

CARLA_VERSION=658b5e30c6457fe9ef9a839e06a49912bb4feee2 # 2.5.1~
CARLA_URL=https://github.com/falkTX/Carla.git

# ---------------------------------------------------------------------------------------------------------------------
# check if lv2lint is supported

LV2LINT_SUPPORTED=1

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    LV2LINT_SUPPORTED=0
fi

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap qt stuff

if [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    QT5_VERSION=5.12.12
    QT5_MVERSION=5.12
else
    QT5_VERSION=5.9.8
    QT5_MVERSION=5.9
fi

QT5_URL=https://download.qt.io/archive/qt/${QT5_MVERSION}/${QT5_VERSION}/submodules

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap carla stuff

FILE_VERSION=5.34
FILE_URL=ftp://ftp.astron.com/pub/file

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    CXFREEZE_VERSION=a59a0f6c476554c1a789de2a9f6f77329d6a6dd1 # 6.8.4
    PYTHON_VERSION=3.9.5
    PYLIBLO_VERSION=0.10.0
    PYQT5_VERSION=5.13.1
    SIP_VERSION=4.19.19
    # extra, needed for pyliblo
    CYTHON_VERSION=0.29.21
    # extra, needed for cxfreeze
    IMPORTLIB_METADATA_VERSION=4.10.1
    SETUPTOOLS_SCM_VERSION=5.0.0
    TOML_VERSION=0.10.2
    ZIPP_VERSION=3.4.0
elif [ "${WIN32}" -eq 1 ]; then
    CXFREEZE_VERSION=6c1d6f23f401d40368d4fab5cd710a784b114a12 # 6.1
    PYTHON_VERSION=3.8.7
    PYLIBLO_VERSION=0.9.2
    PYQT5_VERSION=5.13.1
    SIP_VERSION=4.19.19
else
    CXFREEZE_VERSION=6c1d6f23f401d40368d4fab5cd710a784b114a12 # 6.1
    PYTHON_VERSION=3.7.4
    PYLIBLO_VERSION=0.9.2
    PYQT5_VERSION=5.9.2
    SIP_VERSION=4.19.13
fi

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap jack stuff

AFTEN_VERSION=0.0.8
AFTEN_URL=http://downloads.sourceforge.net/aften

DB_VERSION=5.3.28
DB_URL=https://download.oracle.com/berkeley-db

PORTAUDIO_VERSION=19.6.0
PORTAUDIO_URL=http://deb.debian.org/debian/pool/main/p/portaudio19

RTAUDIO_VERSION=e03448bd15c1c34e842459939d755f5f89e880ed
RTAUDIO_URL=https://github.com/falkTX/rtaudio.git

TRE_VERSION=6092368aabdd0dbb0fbceb2766a37b98e0ff6911
TRE_URL=https://github.com/laurikari/tre.git

# ---------------------------------------------------------------------------------------------------------------------
