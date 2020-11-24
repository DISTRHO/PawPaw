#!/bin/bash

set -e

# nothing to do for macOS native
if [ "${TARGET}" = "macos" ]; then
    exit 0
fi

# Special handling for caching deb archives
if [ "$(ls ${HOME}/PawPawBuilds/debs | wc -l)" -ne 0 ]; then
    sudo cp ${HOME}/PawPawBuilds/debs/*.deb /var/cache/apt/archives/
fi

# common
sudo apt-get install -y build-essential curl cmake jq meson

# specific
if [ "${TARGET}" = "linux" ]; then
    sudo apt-get install -y libglib2.0-dev

elif [ "${TARGET}" = "macos-old" ]; then
    mkdir -p ${HOME}/PawPawBuilds/debs
    pushd ${HOME}/PawPawBuilds/debs
    if [ ! -f 'apple-uni-sdk-10.5_20110407-0.flosoft1_amd64.deb' ]; then
        wget -c 'https://launchpad.net/~kxstudio-debian/+archive/ubuntu/toolchain/+files/apple-uni-sdk-10.5_20110407-0.flosoft1_amd64.deb'
    fi
    if [ ! -f 'apple-x86-odcctools_758.159-0kxstudio2_amd64.deb' ]; then
        wget -c 'https://launchpad.net/~kxstudio-debian/+archive/ubuntu/toolchain/+files/apple-x86-odcctools_758.159-0kxstudio2_amd64.deb'
    fi
    if [ ! -f 'apple-x86-gcc_4.2.1~5646-1kxstudio2_amd64.deb' ]; then
        wget -c 'https://launchpad.net/~kxstudio-debian/+archive/ubuntu/toolchain/+files/apple-x86-gcc_4.2.1~5646-1kxstudio2_amd64.deb'
    fi
    sudo dpkg -i 'apple-uni-sdk-10.5_20110407-0.flosoft1_amd64.deb'
    sudo dpkg -i 'apple-x86-odcctools_758.159-0kxstudio2_amd64.deb'
    sudo dpkg -i 'apple-x86-gcc_4.2.1~5646-1kxstudio2_amd64.deb'
    popd

elif [ "${TARGET}" = "win32" ]; then
    sudo apt-get install -y mingw-w64 binfmt-support binutils-mingw-w64-i686 g++-mingw-w64-i686 winehq-stable wine-binfmt

elif [ "${TARGET}" = "win64" ]; then
    sudo apt-get install -y mingw-w64 binfmt-support binutils-mingw-w64-x86-64 g++-mingw-w64-x86-64 winehq-stable wine-binfmt

fi

# Special handling for caching deb archives
sudo mv /var/cache/apt/archives/*.deb ${HOME}/PawPawBuilds/debs/
