#!/bin/bash

set -e

if [ x"${1}" = x"" ]; then
    echo "usage: $0 <target>"
    exit 1
fi

EMSCRIPTEN_VERSION=${EMSCRIPTEN_VERSION:=latest}

function get_linux_deb_arch() {
    case "${1}" in
        "linux-aarch64") echo "arm64" ;;
        "linux-armhf") echo "armhf" ;;
        "linux-i686") echo "i386" ;;
        "linux-riscv64") echo "riscv64" ;;
        "linux-x86_64") echo "amd64" ;;
        "win32"|"win64") echo "i386" ;;
    esac
}

function install_compiler() {
    case "${1}" in
        "linux-aarch64")
            apt-get install -yqq g++-aarch64-linux-gnu
        ;;
        "linux-armhf")
            apt-get install -yqq g++-arm-linux-gnueabihf
        ;;
        "linux-i686")
            apt-get install -yqq g++-i686-linux-gnu
        ;;
        "linux-riscv64")
            apt-get install -yqq g++-riscv64-linux-gnu
        ;;
        "linux-x86_64")
            # FIXME this assumes build runner is x86_64
            apt-get install -yqq g++
        ;;
        "wasm")
            [ -e ~/PawPawBuilds/emsdk ] || git clone https://github.com/emscripten-core/emsdk.git ~/PawPawBuilds/emsdk
            cd ~/PawPawBuilds/emsdk && ./emsdk install ${EMSCRIPTEN_VERSION} && ./emsdk activate ${EMSCRIPTEN_VERSION}
        ;;
        "win32")
            apt-get install -yqq binutils-mingw-w64-i686 g++-mingw-w64-i686 mingw-w64 wine-stable
        ;;
        "win64")
            apt-get install -yqq binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64 mingw-w64 wine-stable
        ;;
    esac
}

case "${1}" in
    "macos"|"macos-universal"|"macos-universal-10.15")
        brew install cmake git jq meson
    ;;
    *)
        sed -i "s/deb http/deb [arch=amd64] http/" /etc/apt/sources.list
        sed -i "s/deb mirror/deb [arch=amd64] mirror/" /etc/apt/sources.list
        apt-get update -qq
        apt-get install -yqq autoconf automake autopoint binfmt-support build-essential curl cmake git jq lsb-release meson gperf qemu-user-static

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
            apt-get install -y libasound2-dev:${arch} libdbus-1-dev:${arch} libgl1-mesa-dev:${arch} libglib2.0-dev:${arch} liblo-dev:${arch} libx11-dev:${arch} libxcursor-dev:${arch} libxext-dev:${arch} libxrandr-dev:${arch}
        fi

        install_compiler "${1}"
    ;;
esac
