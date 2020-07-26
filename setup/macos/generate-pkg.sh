#!/bin/bash

set -e

cd $(dirname ${0})

# ---------------------------------------------------------------------------------------------------------------------

installed_prefix="${1}"

if [ -z "${installed_prefix}" ]; then
    echo "usage: ${0} <installed_prefix>"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------

VERSION=$(cat ../../VERSION)

rm -f PawPaw-macOS-root.pkg
rm -f PawPaw-macOS-${VERSION}.pkg
rm -f package.xml

# ---------------------------------------------------------------------------------------------------------------------

pkgbuild \
	--identifier studio.kx.distrho.pawpaw \
	--install-location "/usr/local/" \
	--root "${installed_prefix}/" \
	PawPaw-macOS-root.pkg

# ---------------------------------------------------------------------------------------------------------------------

# https://developer.apple.com/library/content/documentation/DeveloperTools/Reference/DistributionDefinitionRef/Chapters/Distribution_XML_Ref.html

sed -e "s|@CURDIR@|${PWD}|" package.xml.in > package.xml

productbuild \
	--distribution package.xml \
	--identifier studio.kx.distrho.pawpaw \
	--package-path "${PWD}" \
	--version ${VERSION} \
	PawPaw-macOS-v${VERSION}.pkg

rm package.xml

# ---------------------------------------------------------------------------------------------------------------------
