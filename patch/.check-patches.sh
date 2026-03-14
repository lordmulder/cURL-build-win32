#!/bin/bash
#                              _   _ ____  _
#                          ___| | | |  _ \| |
#                         / __| | | | |_) | |
#                        | (__| |_| |  _ <| |___
#                         \___|\___/|_| \_\_____|

set -euo pipefail

readonly CURL_VER="8.19.0"
readonly BASE_DIR="$(realpath "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..")"
readonly TEMP_DIR="$(mktemp -d)"

trap "rm -rf \"${TEMP_DIR}\"" EXIT

function apply_patch() {
	test -n "${1}"
	printf "\e[96m[${1}]\e[0m\n"
	patch --fuzz=0 -p1 -b < "${BASE_DIR}/patch/${1}"
}

curl --proto '=https' --tlsv1.2 -sSf "https://curl.se/download/curl-${CURL_VER}.tar.gz" | tar -C "${TEMP_DIR}" --strip-components=1 -xz
pushd "${TEMP_DIR}"

apply_patch "curl_getenv.diff"
apply_patch "curl_threads.diff"
apply_patch "curl_fopen.diff"
apply_patch "curl_tool_doswin.diff"
apply_patch "curl_tool_getparam.diff"
apply_patch "curl_tool_operate.diff"
apply_patch "curl_tool_parsecfg.diff"
apply_patch "curl_tool_util.diff"

popd
