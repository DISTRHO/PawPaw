#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------
# common URLs

DROBILLA_URL=http://download.drobilla.net
XIPH_URL=https://downloads.xiph.org/releases

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap base

PKG_CONFIG_URL=https://pkg-config.freedesktop.org/releases
PKG_CONFIG_VERSION=0.28

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap common

LIBOGG_URL=${XIPH_URL}/ogg
LIBOGG_VERSION=1.3.5

LIBVORBIS_URL=${XIPH_URL}/vorbis
LIBVORBIS_VERSION=1.3.7

FLAC_URL=${XIPH_URL}/flac
FLAC_VERSION=1.3.3

OPUS_URL=https://archive.mozilla.org/pub/opus
OPUS_VERSION=1.3.1

LIBSNDFILE_URL=https://github.com/libsndfile/libsndfile/releases/download/1.0.31
LIBSNDFILE_VERSION=1.0.31

LIBSAMPLERATE_URL=http://www.mega-nerd.com/SRC
LIBSAMPLERATE_VERSION=0.1.9

ZLIB_URL=https://github.com/madler/zlib.git
ZLIB_VERSION=cacf7f1d4e3d44d871b605da3b647f07d718623f # 1.2.11

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap plugins

FFTW_URL=http://www.fftw.org
FFTW_VERSION=3.3.9

GLIB_URL=http://download.gnome.org/sources/glib/2.22
GLIB_MVERSION=2.22
GLIB_VERSION=2.22.5

LIBLO_URL=http://download.sourceforge.net/liblo
LIBLO_VERSION=0.30

PCRE_URL=https://ftp.pcre.org/pub/pcre
PCRE_VERSION=8.44

LV2_URL=https://gitlab.com/lv2/lv2.git
LV2_VERSION=6cefc7df1a6158c79d23029df183c09b10b88cad

SERD_URL=${DROBILLA_URL}
SERD_VERSION=0.30.8

SORD_URL=${DROBILLA_URL}
SORD_VERSION=0.16.8

SRATOM_URL=${DROBILLA_URL}
SRATOM_VERSION=0.6.8

LILV_URL=${DROBILLA_URL}
LILV_VERSION=0.24.12

LV2LINT_URL=https://gitlab.com/OpenMusicKontrollers/lv2lint/-/archive/0.8.0
LV2LINT_VERSION=0.8.0

KXSTUDIO_LV2_EXTENSIONS_URL=https://github.com/KXStudio/LV2-Extensions.git
KXSTUDIO_LV2_EXTENSIONS_VERSION=fae65fbc173cd2c4367e85917a6ef97280532d88

MOD_SDK_URL=https://github.com/moddevices/mod-sdk.git
MOD_SDK_VERSION=2fe7c7728faa551b2838baa49c0d1953c64f2151

FLUIDSYNTH_URL=https://github.com/FluidSynth/fluidsynth.git
FLUIDSYNTH_VERSION=f65c6ba25fb2c7e37c89fc6a4afc5aa645e208c2 # 1.1.11

MXML_URL=https://github.com/michaelrsweet/mxml.git
MXML_VERSION=38b044ed8ca2a611ed9ed3e26c4b46416335194e # 3.2

CARLA_URL=https://github.com/falkTX/Carla.git
CARLA_VERSION=ca44f4bc538690e76f4e02544f047ad9d559a1b8

# ---------------------------------------------------------------------------------------------------------------------
# check if lv2lint is supported

LV2LINT_SUPPORTED=1

if [ "${MACOS_OLD}" -eq 1 ] || [ "${CROSS_COMPILING}" -eq 1 ]; then
    LV2LINT_SUPPORTED=0
fi
if [ "${MACOS}" -eq 1 ] && [ "$(uname -r)" = "12.6.0" ]; then
    LV2LINT_SUPPORTED=0
fi

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap qt stuff

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    QT5_VERSION=5.12.11
    QT5_MVERSION=5.12
else
    QT5_VERSION=5.9.8
    QT5_MVERSION=5.9
fi

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap carla

FILE_VERSION=5.34
LIBFFI_VERSION=3.3

if [ "${MACOS_UNIVERSAL}" -eq 1 ]; then
    CXFREEZE_VERSION=e1c33afea842bc61dac82145a8a0be5fbd318a92 # 6.4.2
    PYTHON_VERSION=3.9.5
    PYLIBLO_VERSION=0.10.0
    PYQT5_VERSION=5.13.1
    SIP_VERSION=4.19.19
    # extra, needed for pyliblo
    CYTHON_VERSION=0.29.21
    # extra, needed for cxfreeze
    IMPORTLIB_METADATA_VERSION=3.1.1
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
# bootstrap jack

AFTEN_VERSION=0.0.8
DB_VERSION=5.3.28
PORTAUDIO_VERSION=19.6.0
RTAUDIO_VERSION=e03448bd15c1c34e842459939d755f5f89e880ed
TRE_VERSION=6092368aabdd0dbb0fbceb2766a37b98e0ff6911

# ---------------------------------------------------------------------------------------------------------------------
