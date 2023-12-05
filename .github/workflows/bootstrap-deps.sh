#!/bin/bash

set -e

if [ x"${1}" = x"" ]; then
    echo "usage: $0 <target>"
    exit 1
fi

function get_linux_deb_arch() {
    case "${1}" in
        "linux-aarch64") echo "arm64" ;;
        "linux-armhf") echo "armhf" ;;
        "linux-i686") echo "i386" ;;
        "linux-riscv64") echo "riscv64" ;;
        "linux-x86_64") echo "amd64" ;;
    esac
}

function install_compiler() {
    case "${1}" in
        "linux-aarch64")
            if [ "$(uname -m)" != "aarch64" ]; then
                apt-get install -yqq g++-aarch64-linux-gnu
            else
                apt-get install -yqq g++
            fi
        ;;
        "linux-armhf")
            if [ "$(uname -m)" != "armhf" ]; then
                apt-get install -yqq g++-arm-linux-gnueabihf
            else
                apt-get install -yqq g++
            fi
        ;;
        "linux-i686")
            if [ "$(uname -m)" != "i686" ]; then
                apt-get install -yqq g++-i686-linux-gnu
            else
                apt-get install -yqq g++
            fi
        ;;
        "linux-riscv64")
            if [ "$(uname -m)" != "riscv64" ]; then
                apt-get install -yqq g++-riscv64-linux-gnu
            else
                apt-get install -yqq g++
            fi
        ;;
        "linux-x86_64")
            if [ "$(uname -m)" != "x86_64" ]; then
                apt-get install -yqq g++-x86_64-linux-gnu
            else
                apt-get install -yqq g++
            fi
        ;;
        "win32")
            dpkg --add-architecture i386
            apt-get update -qq
            apt-get install -yqq binutils-mingw-w64-i686 g++-mingw-w64-i686 mingw-w64
            if [ "$(lsb_release -si 2>/dev/null)" = "Debian" ]; then
                apt-get install -yqq wine wine32
            else
                apt-get install -yqq wine-stable
            fi
        ;;
        "win64")
            dpkg --add-architecture i386
            apt-get update -qq
            apt-get install -yqq binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64 mingw-w64
            if [ "$(lsb_release -si 2>/dev/null)" = "Debian" ]; then
                apt-get install -yqq wine wine32 wine64
            else
                apt-get install -yqq wine-stable
            fi
        ;;
    esac
}

case "${1}" in
    "macos"|"macos-universal"|"macos-universal-10.15")
        brew install cmake git jq meson

        [ -n "${GITHUB_ENV}" ] && echo "PAWPAW_PACK_NAME=${1}-$(sw_vers -productVersion)" >> "${GITHUB_ENV}"
    ;;
    *)
        apt-get update -qq
        apt-get install -yqq autoconf automake autopoint build-essential curl cmake dpkg-dev file git jq libtool lsb-release meson gperf patchelf

        arch=$(get_linux_deb_arch "${1}")
        release=$(lsb_release -cs 2>/dev/null)

        if [ -n "${arch}" ]; then
            if [ "$(lsb_release -si 2>/dev/null)" = "Ubuntu" ]; then
                sed -i "s/deb http/deb [arch=i386,amd64] http/" /etc/apt/sources.list
                sed -i "s/deb mirror/deb [arch=i386,amd64] mirror/" /etc/apt/sources.list
                if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ]; then
                    echo "deb [arch=${arch}] http://ports.ubuntu.com/ubuntu-ports ${release} main restricted universe multiverse" | tee -a /etc/apt/sources.list
                    echo "deb [arch=${arch}] http://ports.ubuntu.com/ubuntu-ports ${release}-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list
                    echo "deb [arch=${arch}] http://ports.ubuntu.com/ubuntu-ports ${release}-backports main restricted universe multiverse" | tee -a /etc/apt/sources.list
                fi
            fi

            dpkg --add-architecture ${arch}
            apt-get update -qq
            apt-get install -yqq \
                binfmt-support \
                qemu-user-static \
                libasound2-dev:${arch} \
                libdbus-1-dev:${arch} \
                libgl1-mesa-dev:${arch} \
                libglib2.0-dev:${arch} \
                libpcre2-dev:${arch} \
                libpcre3-dev:${arch} \
                libx11-dev:${arch} \
                libxcb1-dev:${arch} \
                libxcursor-dev:${arch} \
                libxext-dev:${arch} \
                libxfixes-dev:${arch} \
                libxrandr-dev:${arch} \
                libxrender-dev:${arch} \
                uuid-dev:${arch}
        fi
        # libqt5svg5-dev qtbase5-dev qtbase5-dev-tools

        case "${release}" in
            "bionic"|"focal")
                apt-get install -yqq python3-pkg-resources
                curl -sOL https://launchpad.net/~kxstudio-debian/+archive/ubuntu/toolchain/+files/meson_0.56.0-1kxstudio4_all.deb
                if [ "${release}" = "bionic" ]; then
                    curl -sOL https://launchpad.net/~kxstudio-debian/+archive/ubuntu/toolchain/+files/cmake_3.13.4-1kxstudio1_$(dpkg-architecture -qDEB_HOST_ARCH).deb
                    curl -sOL https://launchpad.net/~kxstudio-debian/+archive/ubuntu/toolchain/+files/cmake-data_3.13.4-1kxstudio1_all.deb
                fi
                dpkg -i *.deb
                rm *.deb
            ;;
        esac

        install_compiler "${1}"

        [ -n "${GITHUB_ENV}" ] && echo "PAWPAW_PACK_NAME=${1}-${release}" >> "${GITHUB_ENV}"
    ;;
esac
