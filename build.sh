#!/bin/bash
#                                 _   _ ____  _
#                             ___| | | |  _ \| |
#                            / __| | | | |_) | |
#                           | (__| |_| |  _ <| |___
#                            \___|\___/|_| \_\_____|

set -e

readonly MY_MARCH=i386
readonly MY_MTUNE=intel

readonly BASE_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
readonly DEPS_DIR="${BASE_DIR}/.deps"

find "${BASE_DIR}" -maxdepth 1 -type d -name '*-src' -exec rm -rf "{}" \;
rm -rf "${DEPS_DIR}" && mkdir "${DEPS_DIR}" "${DEPS_DIR}/include" "${DEPS_DIR}/lib"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Download
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
wget -4 -P "${DEPS_DIR}" https://zlib.net/zlib-1.2.11.tar.gz
wget -4 -P "${DEPS_DIR}" https://github.com/facebook/zstd/releases/download/v1.5.0/zstd-1.5.0.tar.gz
wget -4 -P "${DEPS_DIR}" https://github.com/google/brotli/archive/v1.0.9/brotli-1.0.9.tar.gz
wget -4 -P "${DEPS_DIR}" https://www.openssl.org/source/openssl-1.1.1k.tar.gz
wget -4 -P "${DEPS_DIR}" https://github.com/nghttp2/nghttp2/releases/download/v1.43.0/nghttp2-1.43.0.tar.gz
wget -4 -P "${DEPS_DIR}" https://curl.se/download/curl-7.77.0.tar.gz
wget -4 -P "${DEPS_DIR}" https://curl.se/ca/cacert.pem

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# zlib
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== zlib ====================\n\n"
readonly ZLIB_DIR="${BASE_DIR}/zlib-src"
pkg_zlib="$(find "${DEPS_DIR}" -maxdepth 1 -name 'zlib-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${ZLIB_DIR}" && mkdir "${ZLIB_DIR}"
tar -xvf ${pkg_zlib} --strip-components=1 -C "${ZLIB_DIR}"
pushd "${ZLIB_DIR}"
make -f win32/Makefile.gcc libz.a LOC="-march=${MY_MARCH} -mtune=${MY_MTUNE}"
cp -vf libz.a "${DEPS_DIR}/lib"
cp -vf zlib.h zconf.h "${DEPS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Zstandard
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Zstandard ====================\n\n"
readonly ZSTD_DIR="${BASE_DIR}/zstd-src"
pkg_zstd="$(find "${DEPS_DIR}" -maxdepth 1 -name 'zstd-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${ZSTD_DIR}" && mkdir "${ZSTD_DIR}"
tar -xvf ${pkg_zstd} --strip-components=1 -C "${ZSTD_DIR}"
pushd "${ZSTD_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE}" make lib
cp -vf lib/libzstd.a "${DEPS_DIR}/lib"
cp -vf lib/zstd.h lib/zstd_errors.h "${DEPS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Brotli
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Brotli ====================\n\n"
readonly BROT_DIR="${BASE_DIR}/brotli-src"
pkg_brot="$(find "${DEPS_DIR}" -maxdepth 1 -name 'brotli-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${BROT_DIR}" && mkdir "${BROT_DIR}"
tar -xvf ${pkg_brot} --strip-components=1 -C "${BROT_DIR}"
pushd "${BROT_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE}" make lib
mkdir -p "${DEPS_DIR}/include/brotli"
cp -vf libbrotli.a "${DEPS_DIR}/lib/libbrotlienc.a"
cp -vf libbrotli.a "${DEPS_DIR}/lib/libbrotlidec.a"
cp -vf c/include/brotli/*.h "${DEPS_DIR}/include/brotli"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# OpenSSL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== OpenSSL ====================\n\n"
readonly OSSL_DIR="${BASE_DIR}/openssl-src"
pkg_ossl="$(find "${DEPS_DIR}" -maxdepth 1 -name 'openssl-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${OSSL_DIR}" && mkdir "${OSSL_DIR}"
tar -xvf ${pkg_ossl} --strip-components=1 -C "${OSSL_DIR}"
pushd "${OSSL_DIR}"
./Configure no-hw no-shared no-engine no-capieng no-dso 386 zlib -static -march=${MY_MARCH} -mtune=${MY_MTUNE} -I"${DEPS_DIR}/include" -L"${DEPS_DIR}/lib" -latomic mingw
make build_libs
mkdir -p "${DEPS_DIR}/include/crypto" "${DEPS_DIR}/include/openssl"
cp -vf libcrypto.a libssl.a "${DEPS_DIR}/lib"
cp -vf include/crypto/*.h "${DEPS_DIR}/include/crypto"
cp -vf include/openssl/*.h "${DEPS_DIR}/include/openssl"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# nghttp2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== nghttp2 ====================\n\n"
readonly NGH2_DIR="${BASE_DIR}/nghttp2-src"
pkg_ngh2="$(find "${DEPS_DIR}" -maxdepth 1 -name 'nghttp2-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${NGH2_DIR}" && mkdir "${NGH2_DIR}"
tar -xvf ${pkg_ngh2} --strip-components=1 -C "${NGH2_DIR}"
pushd "${NGH2_DIR}"
CFLAGS="-march=i386 -mtune=intel" OPENSSL_CFLAGS="-I\"${DEPS_DIR}/include\"" OPENSSL_LIBS="-L\"${DEPS_DIR}/lib\" -lssl -lcrypto" ZLIB_CFLAGS="-I\"${DEPS_DIR}/include\"" ZLIB_LIBS="-L\"${DEPS_DIR}/lib\" -lz" ./configure --enable-lib-only --disable-threads --disable-shared
make
mkdir -p "${DEPS_DIR}/include/nghttp2"
cp -v lib/.libs/libnghttp2.a "${DEPS_DIR}/lib"
cp -v lib/includes/nghttp2/*.h "${DEPS_DIR}/include/nghttp2"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cURL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== cURL ====================\n\n"
readonly CURL_DIR="${BASE_DIR}/curl-src"
pkg_curl="$(find "${DEPS_DIR}" -maxdepth 1 -name 'curl-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${CURL_DIR}" && mkdir "${CURL_DIR}"
tar -xvf ${pkg_curl} --strip-components=1 -C "${CURL_DIR}"
pushd "${CURL_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/curl_mutex_init.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${DEPS_DIR}/include\"" LDFLAGS="-static -no-pthread -L\"${DEPS_DIR}/lib\"" LIBS="-latomic -lcrypt32" ./configure --disable-shared --disable-pthreads --enable-static --disable-ldap --with-zlib="${DEPS_DIR}" --with-zstd="${DEPS_DIR}" --with-brotli="${DEPS_DIR}" --with-openssl="${DEPS_DIR}" --with-nghttp2="${DEPS_DIR}" --with-ca-bundle="cacert.pem"
make curl_LDFLAGS=-all-static
cp -vf "${CURL_DIR}/src/curl.exe" "${BASE_DIR}/curl.exe"
cp -vf "${DEPS_DIR}/cacert.pem" "${BASE_DIR}/cacert.pem"
strip -s "${BASE_DIR}/curl.exe"
popd

printf "\nCompleted.\n\n"
