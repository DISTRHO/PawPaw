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

# TODO check that bootstrap.sh has been run

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh
source setup/functions.sh
source setup/versions.sh

# ---------------------------------------------------------------------------------------------------------------------

LV2DIR="${PAWPAW_PREFIX}/lib/lv2"

if [ "${WIN32}" -eq 1 ] && [ ! -d "${HOME}/.wine" ]; then
    env WINEARCH="${PAWPAW_TARGET}" WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u
fi

function validate_lv2_bundle() {
    local lv2bundle="${1}"

    rm -rf /tmp/pawpaw-plugin-check
    mkdir /tmp/pawpaw-plugin-check
    cp -r "${LV2DIR}/${lv2bundle}" /tmp/pawpaw-plugin-check/

    env LANG=C LV2_PATH="${LV2DIR}" PATH="${PAWPAW_PREFIX}/bin:${PATH}" \
        "${PAWPAW_PREFIX}/bin/lv2_validate" \
            "${LV2DIR}/kx-*/*.ttl" \
            "${LV2DIR}/mod.lv2/*.ttl" \
            "${LV2DIR}/modgui.lv2/*.ttl" \
            "/tmp/pawpaw-plugin-check/${lv2bundle}/*.ttl" 1>&2

    local ret=$?

    if [ "${CROSS_COMPILING}" -eq 0 ] || [ -n "${EXE_WRAPPER}" ]; then
        env LANG=C LV2_PATH=/tmp/pawpaw-plugin-check WINEDEBUG=-all \
            ${EXE_WRAPPER} \
            "${PAWPAW_PREFIX}/bin/lv2ls${APP_EXT}" | tr -d '\r'
    fi

    rm -rf /tmp/pawpaw-plugin-check

    return ${ret}
}

function validate_lv2_plugin() {
    local lv2plugin="${1}"

    local carlaenv="CARLA_BRIDGE_DUMMY=1"

    if [ "${WIN64}" -eq 1 ]; then
        carlaenv+=" CARLA_BRIDGE_TESTING=win64"
    elif [ "${WIN32}" -eq 1 ]; then
        carlaenv+=" CARLA_BRIDGE_TESTING=win32"
    else
        carlaenv+=" CARLA_BRIDGE_TESTING=native"
    fi

    env LANG=C LV2_PATH="${LV2DIR}" WINEDEBUG=-all ${carlaenv} \
        "${PAWPAW_PREFIX}/bin/carla-single" lv2 "${lv2plugin}" 1>/dev/null
}

# ---------------------------------------------------------------------------------------------------------------------

exitcode=0

for plugin in ${@}; do
    pfile="${PAWPAW_ROOT}/plugins/${plugin}.json"

    if [ ! -e "${pfile}" ]; then
        echo "Requested plugin file '${pfile}' does not exist"
        exit 2
    fi

    name=$(jq -crM .name ${pfile})
    version=$(jq -crM .version ${pfile})
    buildtype=$(jq -crM .buildtype ${pfile})
    dlbaseurl=$(jq -crM .dlbaseurl ${pfile})
    lv2bundles=($(jq -crM .lv2bundles[] ${pfile}))

    # optional args
    buildargs=$(echo -e $(jq -ecrM .buildargs ${pfile} || echo '\n\n') | tail -n 1)
    dlext=$(echo -e $(jq -ecrM .dlext ${pfile} || echo '\n\n') | tail -n 1)
    dlmethod=$(echo -e $(jq -ecrM .dlmethod ${pfile} || echo '\n\n') | tail -n 1)

    download "${name}" "${version}" "${dlbaseurl}" "${dlext}" "${dlmethod}"

    case ${buildtype} in
        "autoconf")
            build_autoconf "${name}" "${version}" "${buildargs}"
            ;;
        "conf")
            build_conf "${name}" "${version}" "${buildargs}"
            ;;
        "cmake")
            build_cmake "${name}" "${version}" "${buildargs}"
            ;;
        "make")
            build_make "${name}" "${version}" "${buildargs}"
            ;;
        "meson")
            build_meson "${name}" "${version}" "${buildargs}"
            ;;
        "waf")
            build_waf "${name}" "${version}" "${buildargs}"
            ;;
    esac

    # check if plugin needs validation
    pkgdir="${PAWPAW_BUILDDIR}/${name}-${version}"
    if [ -f "${pkgdir}/.stamp_verified" ]; then
        continue
    fi

    # cannot run validation on certain setups
    if [ "${CROSS_COMPILING}" -eq 1 ] && [ -z "${EXE_WRAPPER}" ]; then
        continue
    fi

    # validate all bundles
    validationfail=0
    for lv2bundle in ${lv2bundles[@]}; do
        echo -n "Validating ${lv2bundle}... "
        if [ ! -f "${LV2DIR}/${lv2bundle}/manifest.ttl" ]; then
            echo "manifest.ttl file missing"
            exitcode=1
            validationfail=1
            continue
        fi

        echo

        # lv2 metadata validation
        lv2plugins=($(validate_lv2_bundle "${lv2bundle}"))

        # lv2 plugin count
        echo "Found ${#lv2plugins[@]} plugin(s)"

        # real host test
        for lv2plugin in ${lv2plugins[@]}; do
            echo -n "Verifying ${lv2plugin}... "
            validate_lv2_plugin ${lv2plugin}
            echo "ok"
        done
    done

    if [ "${validationfail}" -eq 0 ]; then
        touch "${pkgdir}/.stamp_verified"
    fi
done

exit ${exitcode}

# ---------------------------------------------------------------------------------------------------------------------
