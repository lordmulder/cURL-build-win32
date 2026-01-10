#!/bin/bash
#                              _   _ ____  _
#                          ___| | | |  _ \| |
#                         / __| | | | |_) | |
#                        | (__| |_| |  _ <| |___
#                         \___|\___/|_| \_\_____|

set -eo pipefail

readonly CURL_VER="8.18.0"
readonly BASE_DIR="$(realpath "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
readonly TEMP_DIR="$(mktemp -d)"

trap "rm -rf \"${TEMP_DIR}\"" EXIT

curl --proto '=https' --tlsv1.2 -sSf "https://curl.se/download/curl-${CURL_VER}.tar.gz" | tar -C "${TEMP_DIR}" --strip-components=1 -xz

pushd "${TEMP_DIR}"

patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_getenv.diff"
patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_threads.diff"
patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_tool_doswin.diff"
patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_tool_getparam.diff"
patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_tool_operate.diff"
patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_tool_parsecfg.diff"
patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/curl_tool_util.diff"

popd
