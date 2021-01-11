#!/bin/bash

set -e

if [ -z "${BOOTSTRAP_VERSION}" ]; then
    echo "Script only intended for travis/CI use"
    exit 1
fi

if [ -e ${HOME}/PawPawBuilds/builds/.last-bootstrap-version ]; then
    LAST_BOOTSTRAP_VERSION=$(cat ${HOME}/PawPawBuilds/builds/.last-bootstrap-version)
else
    LAST_BOOTSTRAP_VERSION=0
fi

# PLUGINS_BASE="abgate artyfx caps die-plugins fomp mda"
# PLUGINS_CROSS="blop dpf-plugins ninjas2"
# PLUGINS_DISTRHO="distrho-ports-arctican distrho-ports-drowaudio distrho-ports-tal-plugins"

# only build full set of distrho-ports if we have previously cached builds, otherwise we time-out in travis
if [ ${LAST_BOOTSTRAP_VERSION} -eq ${BOOTSTRAP_VERSION} ]; then
    PLUGINS_DISTRHO+=" distrho-ports-dexed"
    PLUGINS_DISTRHO+=" distrho-ports-klangfalter"
    PLUGINS_DISTRHO+=" distrho-ports-luftikus"
    PLUGINS_DISTRHO+=" distrho-ports-obxd"
    PLUGINS_DISTRHO+=" distrho-ports-pitched-delay"
    PLUGINS_DISTRHO+=" distrho-ports-refine"
    PLUGINS_DISTRHO+=" distrho-ports-temper"
    PLUGINS_DISTRHO+=" distrho-ports-vex"
    PLUGINS_DISTRHO+=" distrho-ports-wolpertinger"
fi

if [ "${TARGET}" = "linux" ]; then
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS}"
elif [ "${TARGET}" = "macos-old" ]; then
    PLUGINS="${PLUGINS_BASE}"
else
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS} ${PLUGINS_DISTRHO}"
fi

${TRAVIS_BUILD_DIR}/build-plugins.sh ${TARGET} ${PLUGINS}
${TRAVIS_BUILD_DIR}/.cleanup.sh ${TARGET}

# packing of plugins can only be done when doing a full build
if [ ${LAST_BOOTSTRAP_VERSION} -eq ${BOOTSTRAP_VERSION} ]; then
    ${TRAVIS_BUILD_DIR}/pack-plugins.sh ${TARGET} ${PLUGINS}
fi

echo ${BOOTSTRAP_VERSION} > ${HOME}/PawPawBuilds/builds/.last-bootstrap-version
