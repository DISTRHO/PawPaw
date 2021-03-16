#!/bin/bash

set -e

if [ -z "${BOOTSTRAP_VERSION}" ]; then
    echo "Script only intended for travis/CI use"
    exit 1
fi

# ---------------------------------------------------------------------------------------------------------------------
# check build step

PAWPAW_DIR="${HOME}/PawPawBuilds"
PAWPAW_BUILDDIR="${PAWPAW_DIR}/builds/${TARGET}"

if [ -e ${PAWPAW_BUILDDIR}/.last-bootstrap-version ]; then
    LAST_BOOTSTRAP_VERSION=$(cat ${PAWPAW_BUILDDIR}/.last-bootstrap-version)
else
    LAST_BOOTSTRAP_VERSION=0
fi

if [ ${LAST_BOOTSTRAP_VERSION} -eq ${BOOTSTRAP_VERSION} ] && [ -e ${PAWPAW_BUILDDIR}/.last-build-version ]; then
    LAST_BUILD_VERSION=$(cat ${PAWPAW_BUILDDIR}/.last-build-version)
else
    LAST_BUILD_VERSION=0
fi

BUILD_VERSION=$((${LAST_BUILD_VERSION} + 1))

echo "PawPaw build v${BUILD_VERSION}"

# ---------------------------------------------------------------------------------------------------------------------
# build plugins according to version/step, caching files along the way

# TODO
# ninjas2: need to put http://kxstudio.sf.net/ns/lv2ext/props#NonAutomable spec somewhere

PLUGINS_BASE="abgate artyfx caps die-plugins fomp mda"
PLUGINS_CROSS="blop dpf-plugins"
PLUGINS_DISTRHO=""

if [ ${BUILD_VERSION} -ge 2 ]; then
    PLUGINS_DISTRHO+=" distrho-ports-arctican"
    PLUGINS_DISTRHO+=" distrho-ports-drowaudio"
    PLUGINS_DISTRHO+=" distrho-ports-tal-plugins"
fi

if [ ${BUILD_VERSION} -ge 3 ]; then
    PLUGINS_DISTRHO+=" distrho-ports-dexed"
    PLUGINS_DISTRHO+=" distrho-ports-klangfalter"
    PLUGINS_DISTRHO+=" distrho-ports-luftikus"
    PLUGINS_DISTRHO+=" distrho-ports-obxd"
    PLUGINS_DISTRHO+=" distrho-ports-pitched-delay"
    PLUGINS_DISTRHO+=" distrho-ports-refine"
fi

if [ ${BUILD_VERSION} -ge 4 ]; then
    PLUGINS_DISTRHO+=" distrho-ports-swankyamp"
    PLUGINS_DISTRHO+=" distrho-ports-temper"
    PLUGINS_DISTRHO+=" distrho-ports-vex"
    PLUGINS_DISTRHO+=" distrho-ports-vitalium"
    PLUGINS_DISTRHO+=" distrho-ports-wolpertinger"
fi

# ---------------------------------------------------------------------------------------------------------------------
# build plugins according to target

if [ "${TARGET}" = "linux" ]; then
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS}"
elif [ "${TARGET}" = "macos-old" ]; then
    PLUGINS="${PLUGINS_BASE}"
else
    PLUGINS="${PLUGINS_BASE} ${PLUGINS_CROSS} ${PLUGINS_DISTRHO}"
fi

${TRAVIS_BUILD_DIR}/build-plugins.sh ${TARGET} ${PLUGINS}
${TRAVIS_BUILD_DIR}/.cleanup.sh ${TARGET}

# ---------------------------------------------------------------------------------------------------------------------
# packaging, only be done when doing a full build

if [ ${BUILD_VERSION} -ge 4 ]; then
    ${TRAVIS_BUILD_DIR}/pack-plugins.sh ${TARGET} ${PLUGINS}
fi

# ---------------------------------------------------------------------------------------------------------------------
# set env for next builds

echo ${BOOTSTRAP_VERSION} > ${PAWPAW_BUILDDIR}/.last-bootstrap-version

if [ ${BUILD_VERSION} -le 4 ]; then
    echo ${BUILD_VERSION} > ${PAWPAW_BUILDDIR}/.last-build-version
fi

# ---------------------------------------------------------------------------------------------------------------------
