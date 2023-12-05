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
            apt-get install -yqq binutils-mingw-w64-i686 g++-mingw-w64-i686 mingw-w64 wine-stable
        ;;
        "win64")
            dpkg --add-architecture i386
            apt-get update -qq
            apt-get install -yqq binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64 mingw-w64 wine-stable
        ;;
    esac
}

case "${1}" in
    "macos"|"macos-universal"|"macos-universal-10.15")
        brew install cmake git jq meson

        [ -n "${GITHUB_ENV}" ] && echo "PAWPAW_PACK_NAME=${1}-$(sw_vers -productVersion)" >> "${GITHUB_ENV}"
    ;;
    *)
        sed -i "s/deb http/deb [arch=i386,amd64] http/" /etc/apt/sources.list
        sed -i "s/deb mirror/deb [arch=i386,amd64] mirror/" /etc/apt/sources.list
        apt-get update -qq
        apt-get install -yqq autoconf automake autopoint binfmt-support build-essential curl cmake git jq lsb-release meson gperf patchelf qemu-user-static

        arch=$(get_linux_deb_arch "${1}")
        release=$(lsb_release -cs)

        if [ -n "${arch}" ]; then
            dpkg --add-architecture ${arch}
            if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ]; then
                echo "deb [arch=${arch}] http://ports.ubuntu.com/ubuntu-ports ${release} main restricted universe multiverse" | tee -a /etc/apt/sources.list
                echo "deb [arch=${arch}] http://ports.ubuntu.com/ubuntu-ports ${release}-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list
                echo "deb [arch=${arch}] http://ports.ubuntu.com/ubuntu-ports ${release}-backports main restricted universe multiverse" | tee -a /etc/apt/sources.list
            fi
            apt-get update -qq
            apt-get install -yqq \
                libasound2-dev:${arch} \
                libdbus-1-dev:${arch} \
                libgl1-mesa-dev:${arch} \
                libglib2.0-dev:${arch} \
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

        install_compiler "${1}"

        [ -n "${GITHUB_ENV}" ] && echo "PAWPAW_PACK_NAME=${1}-${release}" >> "${GITHUB_ENV}"
    ;;
esac
