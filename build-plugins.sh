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

mkdir -p "${PAWPAW_BUILDDIR}"
mkdir -p "${PAWPAW_DOWNLOADDIR}"
mkdir -p "${PAWPAW_PREFIX}"
mkdir -p "${PAWPAW_TMPDIR}"

# ---------------------------------------------------------------------------------------------------------------------

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
done

# ---------------------------------------------------------------------------------------------------------------------
