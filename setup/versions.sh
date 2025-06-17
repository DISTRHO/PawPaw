#!/bin/bash

# NOTE `setup/check_target.sh` must be imported before this one

# ---------------------------------------------------------------------------------------------------------------------
# common URLs

DROBILLA_URL=https://download.drobilla.net
XIPH_URL=https://downloads.xiph.org/releases

KXSTUDIO_FILES_URL=https://kx.studio/files

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

FLAC_VERSION=1.5.0
FLAC_URL=${XIPH_URL}/flac

OPUS_VERSION=1.5.2
OPUS_URL=${XIPH_URL}/opus

# TODO libmp3lame
# TODO libmpg123

LIBSNDFILE_VERSION=1.2.2
LIBSNDFILE_URL=https://github.com/libsndfile/libsndfile/releases/download/${LIBSNDFILE_VERSION}

LIBSAMPLERATE_VERSION=0.2.2
LIBSAMPLERATE_URL=https://github.com/libsndfile/libsamplerate/releases/download/${LIBSAMPLERATE_VERSION}

MINGW_STD_THREADS_VERSION=c931bac289dd431f1dd30fc4a5d1a7be36668073
MINGW_STD_THREADS_URL=https://github.com/meganz/mingw-std-threads.git

ZLIB_VERSION=1.3.1
ZLIB_URL=https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap plugins

LIBPNG_VERSION=1.6.43
LIBPNG_URL=http://download.sourceforge.net/libpng

LIBXML2_VERSION=2.12.4
LIBXML2_URL=https://download.gnome.org/sources/libxml2/2.12

PIXMAN_VERSION=0.42.2
PIXMAN_URL=https://cairographics.org/releases

FREETYPE_VERSION=2.13.2
FREETYPE_URL=http://download.sourceforge.net/freetype

FONTCONFIG_VERSION=2.15.0
FONTCONFIG_URL=https://www.freedesktop.org/software/fontconfig/release

# TODO update and adapt to meson
CAIRO_VERSION=1.16.0
CAIRO_URL=https://cairographics.org/releases

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

# FIXME wrong downloads?
# GLIB_URL=https://download.gnome.org/sources/glib/${GLIB_MVERSION}
GLIB_URL=${KXSTUDIO_FILES_URL}

LIBLO_VERSION=0.32
LIBLO_URL=http://download.sourceforge.net/liblo

LV2_VERSION=0bcde338db1c63bbc503b4d1f6d7b55ed43154af # 1.18.10
LV2_URL=https://gitlab.com/lv2/lv2.git

ZIX_VERSION=0.6.2
ZIX_URL=${DROBILLA_URL}

SERD_VERSION=0.32.4
SERD_URL=${DROBILLA_URL}

SORD_VERSION=0.16.18
SORD_URL=${DROBILLA_URL}

SRATOM_VERSION=0.6.18
SRATOM_URL=${DROBILLA_URL}

LILV_VERSION=0.24.26
LILV_URL=${DROBILLA_URL}

LV2LINT_VERSION=0.16.2
# NOTE upstream host is often down
LV2LINT_URL=${KXSTUDIO_FILES_URL}

DARKGLASS_LV2_EXTENSIONS_VERSION=609166185c301a4a217ab5b60559bda800dd336c # 2025-06-17
DARKGLASS_LV2_EXTENSIONS_URL=https://github.com/KXStudio/LV2-Extensions.git

KXSTUDIO_LV2_EXTENSIONS_VERSION=8b5f6cb9cd75e300958c9aacac253d44c964e80b # 2025-06-17
KXSTUDIO_LV2_EXTENSIONS_URL=https://github.com/KXStudio/LV2-Extensions.git

MOD_SDK_VERSION=f4341a6c2b2f50e2eb405b06ce19f9f0b4b1a62b
MOD_SDK_URL=https://github.com/moddevices/mod-lv2-extensions.git

FLUIDSYNTH_VERSION=cbe4003d97332d3a443422eab8d2764428e31130 # 2.0.0 # f65c6ba25fb2c7e37c89fc6a4afc5aa645e208c2 # 1.1.11
FLUIDSYNTH_URL=https://github.com/FluidSynth/fluidsynth.git

MXML_VERSION=3.3.1
MXML_URL=https://github.com/michaelrsweet/mxml/releases/download/v${MXML_VERSION}

CARLA_VERSION=66afe24a08790732cc17d81d4b846a1e0cfa0118 # 2.6.x
CARLA_URL=https://github.com/falkTX/Carla.git

# ---------------------------------------------------------------------------------------------------------------------
# check if lv2lint is supported

LV2LINT_SUPPORTED=1

if [ "${CROSS_COMPILING}" -eq 1 ]; then
    LV2LINT_SUPPORTED=0
fi

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap qt stuff

if [ "${LINUX}" -eq 1 ] || [ "${MACOS_10_15}" -eq 1 ] || [ "${MACOS_UNIVERSAL}" -eq 1 ] || [ "${WIN32}" -eq 1 ]; then
    QT5_VERSION=5.12.12
    QT5_MVERSION=5.12
else
    QT5_VERSION=5.9.8
    QT5_MVERSION=5.9
fi

QT5_URL=https://download.qt.io/new_archive/qt/${QT5_MVERSION}/${QT5_VERSION}/submodules

# ---------------------------------------------------------------------------------------------------------------------
# bootstrap carla stuff

FILE_URL=ftp://ftp.astron.com/pub/file

# try to use same version as host
if [ "${LINUX}" -eq 1 ] && [ -e /usr/bin/file ]; then
    FILE_VERSION=$(/usr/bin/file -v | awk 'sub("file-","")')
else
    FILE_VERSION=5.34
fi

if [ "${LINUX}" -eq 1 ] || [ "${MACOS}" -eq 1 ]; then
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
