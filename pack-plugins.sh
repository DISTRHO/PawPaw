#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target> <plugin1> ..."
    exit 1
fi

shift

VERSION=$(cat VERSION)

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh

# ---------------------------------------------------------------------------------------------------------------------

function download_and_install_innosetup {
    local dlfile="${PAWPAW_DOWNLOADDIR}/innosetup-6.0.5.exe"
    local pkgdir="${PAWPAW_BUILDDIR}/innosetup-6.0.5"

    if [ ! -f "${dlfile}" ]; then
        # FIXME proper dl version
        curl -L https://jrsoftware.org/download.php/is.exe?site=2 -o "${dlfile}"
    fi

    if [ ! -d "${pkgdir}"/drive_c ]; then
        env WINEARCH="${PAWPAW_TARGET}" WINEDLLOVERRIDES="mscoree,mshtml=" WINEPREFIX="${pkgdir}" wineboot -u
    fi

    if [ ! -f "${pkgdir}"/drive_c/InnoSeup/ISCC.exe ]; then
        env WINEARCH="${PAWPAW_TARGET}" WINEPREFIX="${pkgdir}" wine "${dlfile}" /allusers /dir=C:\\InnoSeup /nocancel /norestart /verysilent
    fi
}

function create_innosetup_exe {
    local pkgdir="${PAWPAW_BUILDDIR}/innosetup-6.0.5"
    local iscc="${pkgdir}/drive_c/InnoSeup/ISCC.exe"

    echo "#define VERSION \"${VERSION}\"" > /tmp/pawpaw/version.iss
    env WINEARCH="${PAWPAW_TARGET}" WINEPREFIX="${pkgdir}" wine "${iscc}" "setup/inno/${PAWPAW_TARGET}.iss"
}

# ---------------------------------------------------------------------------------------------------------------------

rm -rf /tmp/pawpaw
mkdir /tmp/pawpaw

if [ "${WIN32}" -eq 1 ]; then
    download_and_install_innosetup
    touch /tmp/pawpaw/components.iss
    touch /tmp/pawpaw/lv2bundles.iss
    PAWPAW_WINE_LV2DIR="Z:$(echo ${PAWPAW_PREFIX} | tr -t '/' '\\')\\lib\\lv2\\"

elif [ "${MACOS}" -eq 1 ] && [ "${MACOS_OLD}" -eq 0 ]; then
    touch /tmp/pawpaw/choices.xml
    touch /tmp/pawpaw/outlines.xml

fi

# ---------------------------------------------------------------------------------------------------------------------

for plugin in ${@}; do
    pfile="${PAWPAW_ROOT}/plugins/${plugin}.json"

    if [ ! -e "${pfile}" ]; then
        echo "Requested plugin file '${pfile}' does not exist"
        exit 2
    fi

    name=$(jq -crM .name ${pfile})
    sname=$(echo ${name} | tr -ds '-' '_')
    description=$(jq -crM .description ${description})
    lv2bundles=($(jq -crM .lv2bundles[] ${pfile}))

    if [ "${WIN32}" -eq 1 ]; then
        echo "Name: ${sname}; Description: \"${name}\"; Types: full;" >> /tmp/pawpaw/components.iss

    elif [ "${MACOS}" -eq 1 ] && [ "${MACOS_OLD}" -eq 0 ]; then
        echo "    <choice id=\"studio.kx.distrho.pawpaw.${sname}\" title=\"${name}\" description=\"${description}\" visible=\"true\">" >> /tmp/pawpaw/choices.xml
        echo "        <line choice=\"studio.kx.distrho.pawpaw.${sname}\"/>" >> /tmp/pawpaw/outlines.xml
    fi

    for lv2bundle in ${lv2bundles[@]}; do
        if [ "${WIN32}" -eq 1 ]; then
            echo "Source: \"${PAWPAW_WINE_LV2DIR}${lv2bundle}\\*\"; DestDir: \"{commoncf}\\LV2\\${lv2bundle}\"; Components: ${sname}; Flags: recursesubdirs" >> /tmp/pawpaw/lv2bundles.iss

        elif [ "${MACOS}" -eq 1 ] && [ "${MACOS_OLD}" -eq 0 ]; then
            bundleref="pawpaw-bundle-${sname}-${lv2bundle}.pkg"
            echo "        <pkg-ref id=\"studio.kx.distrho.pawpaw.${sname}_${lv2bundle}\" version=\"0\">${bundleref}</pkg-ref>" >> /tmp/pawpaw/choices.xml
            pkgbuild \
                --identifier "studio.kx.distrho.pawpaw.${sname}_${lv2bundle}" \
                --install-location "/Library/Audio/Plug-Ins/LV2/${lv2bundle}/" \
                --root "${PAWPAW_PREFIX}/lib/lv2/${lv2bundle}/" \
                "setup/macos/${bundleref}"
        fi
    done

    if [ "${MACOS}" -eq 1 ] && [ "${MACOS_OLD}" -eq 0 ]; then
        echo "    </choice>" >> /tmp/pawpaw/choices.xml
    fi
done

if [ "${WIN32}" -eq 1 ]; then
    create_innosetup_exe

elif [ "${MACOS}" -eq 1 ] && [ "${MACOS_OLD}" -eq 0 ]; then
    pushd setup/macos
    python -c "
with open('package.xml.in', 'r') as fh:
    packagexml = fh.read()
with open('/tmp/pawpaw/choices.xml', 'r') as fh:
    choicesxml = fh.read().strip()
with open('/tmp/pawpaw/outlines.xml', 'r') as fh:
    outlinesxml = fh.read().strip()
print(packagexml.replace('@CURDIR@','${PWD}').replace('@CHOICES@',choicesxml).replace('@OUTLINES@',outlinesxml))" > package.xml
    productbuild \
        --distribution package.xml \
        --identifier studio.kx.distrho.pawpaw \
        --package-path "${PWD}" \
        --version ${VERSION} \
        PawPaw-macOS-v${VERSION}.pkg
    rm package.xml pawpaw-bundle-*
    popd
fi

rm -rf /tmp/pawpaw

# ---------------------------------------------------------------------------------------------------------------------
