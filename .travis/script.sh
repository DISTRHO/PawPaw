#!/bin/bash

set -e

PLUGINS_BASE="abgate artyfx caps die-plugins dpf-plugins fomp mda"
PLUGINS_CROSS="blop"
PLUGINS_DISTRHO1="distrho-ports-arctican distrho-ports-dexed distrho-ports-drowaudio distrho-ports-klangfalter distrho-ports-luftikus distrho-ports-obxd distrho-ports-pitched-delay"
PLUGINS_DISTRHO2="distrho-ports-refine distrho-ports-tal-plugins distrho-ports-temper distrho-ports-vex distrho-ports-wolpertinger"

if [ "${TARGET}" = "linux" ]; then
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS}"
elif [ "${TARGET}" = "macos-old" ]; then
    PLUGINS="${PLUGINS_BASE}"
elif [ "${TARGET}" = "macos" ] || [ "${TARGET}" = "macos-universal" ]; then
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS} ${PLUGINS_DISTRHO1} ${PLUGINS_DISTRHO2}"
elif [ "${TARGET}" = "win32" ] || [ "${TARGET}" = "win64" ]; then
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS} ${PLUGINS_DISTRHO1} ${PLUGINS_DISTRHO2}"
else
    exit 1
fi

${TRAVIS_BUILD_DIR}/build-plugins.sh ${TARGET} ${PLUGINS}
${TRAVIS_BUILD_DIR}/.cleanup.sh ${TARGET}
${TRAVIS_BUILD_DIR}/pack-plugins.sh ${TARGET} ${PLUGINS}
