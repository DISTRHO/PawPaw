#!/bin/bash

set -e

# nothing to do except for macOS native
if [ "${TARGET}" != "macos" ]; then
    exit 0
fi

brew cleanup
find /usr/local/Homebrew \! -regex ".+\.git.+" -delete
