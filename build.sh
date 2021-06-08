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
readonly LIBS_DIR="${BASE_DIR}/.libs"

find "${BASE_DIR}" -maxdepth 1 -type d -name '*-src' -exec rm -rf "{}" \;
rm -rf "${LIBS_DIR}" && mkdir "${LIBS_DIR}" "${LIBS_DIR}/include" "${LIBS_DIR}/lib"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Download
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
wget -4 -P "${LIBS_DIR}" https://zlib.net/zlib-1.2.11.tar.gz
wget -4 -P "${LIBS_DIR}" https://github.com/facebook/zstd/releases/download/v1.5.0/zstd-1.5.0.tar.gz
wget -4 -P "${LIBS_DIR}" https://github.com/google/brotli/archive/v1.0.9/brotli-1.0.9.tar.gz
wget -4 -P "${LIBS_DIR}" https://www.openssl.org/source/openssl-1.1.1k.tar.gz
wget -4 -P "${LIBS_DIR}" https://www.libssh2.org/download/libssh2-1.9.0.tar.gz
wget -4 -P "${LIBS_DIR}" https://github.com/nghttp2/nghttp2/releases/download/v1.43.0/nghttp2-1.43.0.tar.gz
wget -4 -P "${LIBS_DIR}" https://ftp.gnu.org/gnu/libidn/libidn2-2.3.1.tar.gz
wget -4 -P "${LIBS_DIR}" https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz
wget -4 -P "${LIBS_DIR}" https://curl.se/download/curl-7.77.0.tar.gz
wget -4 -P "${LIBS_DIR}" https://curl.se/ca/cacert.pem
wget -4 -P "${LIBS_DIR}" https://curl.se/docs/manpage.html

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# zlib
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== zlib ====================\n\n"
readonly ZLIB_DIR="${BASE_DIR}/zlib-src"
pkg_zlib="$(find "${LIBS_DIR}" -maxdepth 1 -name 'zlib-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${ZLIB_DIR}" && mkdir "${ZLIB_DIR}"
tar -xvf ${pkg_zlib} --strip-components=1 -C "${ZLIB_DIR}"
pushd "${ZLIB_DIR}"
make -f win32/Makefile.gcc libz.a LOC="-march=${MY_MARCH} -mtune=${MY_MTUNE}"
cp -vf libz.a "${LIBS_DIR}/lib"
cp -vf zlib.h zconf.h "${LIBS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Zstandard
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Zstandard ====================\n\n"
readonly ZSTD_DIR="${BASE_DIR}/zstd-src"
pkg_zstd="$(find "${LIBS_DIR}" -maxdepth 1 -name 'zstd-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${ZSTD_DIR}" && mkdir "${ZSTD_DIR}"
tar -xvf ${pkg_zstd} --strip-components=1 -C "${ZSTD_DIR}"
pushd "${ZSTD_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" LDFLAGS="-L\"${LIBS_DIR}/lib\"" make lib
cp -vf lib/libzstd.a "${LIBS_DIR}/lib"
cp -vf lib/zstd.h lib/zstd_errors.h "${LIBS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Brotli
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Brotli ====================\n\n"
readonly BROT_DIR="${BASE_DIR}/brotli-src"
pkg_brot="$(find "${LIBS_DIR}" -maxdepth 1 -name 'brotli-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${BROT_DIR}" && mkdir "${BROT_DIR}"
tar -xvf ${pkg_brot} --strip-components=1 -C "${BROT_DIR}"
pushd "${BROT_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" LDFLAGS="-L\"${LIBS_DIR}/lib\"" make lib
mkdir -p "${LIBS_DIR}/include/brotli"
cp -vf libbrotli.a "${LIBS_DIR}/lib/libbrotlienc.a"
cp -vf libbrotli.a "${LIBS_DIR}/lib/libbrotlidec.a"
cp -vf c/include/brotli/*.h "${LIBS_DIR}/include/brotli"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# OpenSSL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== OpenSSL ====================\n\n"
readonly OSSL_DIR="${BASE_DIR}/openssl-src"
pkg_ossl="$(find "${LIBS_DIR}" -maxdepth 1 -name 'openssl-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${OSSL_DIR}" && mkdir "${OSSL_DIR}"
tar -xvf ${pkg_ossl} --strip-components=1 -C "${OSSL_DIR}"
pushd "${OSSL_DIR}"
./Configure no-hw no-shared no-engine no-capieng no-dso 386 zlib -static -march=${MY_MARCH} -mtune=${MY_MTUNE} -I"${LIBS_DIR}/include" -L"${LIBS_DIR}/lib" -latomic mingw
make build_libs
mkdir -p "${LIBS_DIR}/include/crypto" "${LIBS_DIR}/include/openssl"
cp -vf libcrypto.a libssl.a "${LIBS_DIR}/lib"
cp -vf include/crypto/*.h "${LIBS_DIR}/include/crypto"
cp -vf include/openssl/*.h "${LIBS_DIR}/include/openssl"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libssh2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libssh2 ====================\n\n"
readonly SSH2_DIR="${BASE_DIR}/libssh2-src"
pkg_ssh2="$(find "${LIBS_DIR}" -maxdepth 1 -name 'libssh2-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${SSH2_DIR}" && mkdir "${SSH2_DIR}"
tar -xvf ${pkg_ssh2} --strip-components=1 -C "${SSH2_DIR}"
pushd "${SSH2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" LDFLAGS="-L\"${LIBS_DIR}/lib\"" LIBS="-latomic" ./configure --disable-examples-build --disable-shared --with-libz
make
cp -v src/.libs/libssh2.a "${LIBS_DIR}/lib"
cp -v include/libssh2.h include/libssh2_publickey.h include/libssh2_sftp.h "${LIBS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# nghttp2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== nghttp2 ====================\n\n"
readonly NGH2_DIR="${BASE_DIR}/nghttp2-src"
pkg_ngh2="$(find "${LIBS_DIR}" -maxdepth 1 -name 'nghttp2-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${NGH2_DIR}" && mkdir "${NGH2_DIR}"
tar -xvf ${pkg_ngh2} --strip-components=1 -C "${NGH2_DIR}"
pushd "${NGH2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" LDFLAGS="-L\"${LIBS_DIR}/lib\"" OPENSSL_CFLAGS="-I\"${LIBS_DIR}/include\"" OPENSSL_LIBS="-L\"${LIBS_DIR}/lib\" -lssl -lcrypto" ZLIB_CFLAGS="-I\"${LIBS_DIR}/include\"" ZLIB_LIBS="-L\"${LIBS_DIR}/lib\" -lz" ./configure --enable-lib-only --disable-threads --disable-shared
make
mkdir -p "${LIBS_DIR}/include/nghttp2" "${LIBS_DIR}/pkgconfig"
cp -v lib/.libs/libnghttp2.a "${LIBS_DIR}/lib"
cp -v lib/includes/nghttp2/*.h "${LIBS_DIR}/include/nghttp2"
cp -v lib/libnghttp2.pc "${LIBS_DIR}/pkgconfig"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libiconv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libiconv ====================\n\n"
readonly ICNV_DIR="${BASE_DIR}/libiconv-src"
pkg_icnv="$(find "${LIBS_DIR}" -maxdepth 1 -name 'libiconv-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${ICNV_DIR}" && mkdir "${ICNV_DIR}"
tar -xvf ${pkg_icnv} --strip-components=1 -C "${ICNV_DIR}"
pushd "${ICNV_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" LDFLAGS="-L\"${LIBS_DIR}/lib\"" ./configure --disable-rpath --disable-shared
make
cp -v lib/.libs/libiconv.a "${LIBS_DIR}/lib"
cp -v include/iconv.h "${LIBS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libidn2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libidn2 ====================\n\n"
readonly IDN2_DIR="${BASE_DIR}/libidn2-src"
pkg_idn2="$(find "${LIBS_DIR}" -maxdepth 1 -name 'libidn2-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${IDN2_DIR}" && mkdir "${IDN2_DIR}"
tar -xvf ${pkg_idn2} --strip-components=1 -C "${IDN2_DIR}"
pushd "${IDN2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" LDFLAGS="-L\"${LIBS_DIR}/lib\"" ./configure --disable-shared --disable-doc --without-libiconv-prefix --without-libunistring-prefix --disable-valgrind-tests
make
cp -v lib/.libs/libidn2.a "${LIBS_DIR}/lib"
cp -v lib/idn2.h "${LIBS_DIR}/include"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cURL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== cURL ====================\n\n"
readonly CURL_DIR="${BASE_DIR}/curl-src"
pkg_curl="$(find "${LIBS_DIR}" -maxdepth 1 -name 'curl-*.tar.gz' | sort -rn | head -n1)"
rm -rf "${CURL_DIR}" && mkdir "${CURL_DIR}"
tar -xvf ${pkg_curl} --strip-components=1 -C "${CURL_DIR}"
pushd "${CURL_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/curl_findw32cacert.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_mutex_init.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_parseconfig.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I\"${LIBS_DIR}/include\"" CPPFLAGS="-DNGHTTP2_STATICLIB" LDFLAGS="-static -no-pthread -L\"${LIBS_DIR}/lib\"" LIBS="-latomic -liconv -lcrypt32" PKG_CONFIG_PATH="${LIBS_DIR}/pkgconfig" ./configure --enable-static --disable-shared --disable-pthreads --disable-libcurl-option --with-zlib="${LIBS_DIR}" --with-zstd="${LIBS_DIR}" --with-brotli="${LIBS_DIR}" --with-openssl="${LIBS_DIR}" --with-libssh2="${LIBS_DIR}" --with-nghttp2="${LIBS_DIR}" --with-libidn2="${LIBS_DIR}" --with-ca-bundle="cacert.pem"
make curl_LDFLAGS=-all-static
strip -s src/curl.exe
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Output
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Output ====================\n\n"
readonly OUT_DIR="${BASE_DIR}/.bin"
rm -rf "${OUT_DIR}" && mkdir "${OUT_DIR}"
pushd "${OUT_DIR}"
cp -vf "${CURL_DIR}/src/curl.exe" curl.exe
cp -vf "${LIBS_DIR}/cacert.pem"   cacert.pem
cp -vf "${LIBS_DIR}/manpage.html" manpage.html
mkdir -p "${OUT_DIR}/legal"
unix2dos -n "${CURL_DIR}/COPYING"    legal/curl.COPYING.txt
unix2dos -n "${CURL_DIR}/README"     legal/curl.README.txt
unix2dos -n "${CURL_DIR}/CHANGES"    legal/curl.CHANGES.txt
unix2dos -n "${BROT_DIR}/LICENSE"    legal/brotli.LICENSE.txt
unix2dos -n "${BROT_DIR}/README.md"  legal/brotli.README.md
unix2dos -n "${ICNV_DIR}/AUTHORS"    legal/libiconv.AUTHORS.txt
unix2dos -n "${ICNV_DIR}/COPYING"    legal/libiconv.COPYING.txt
unix2dos -n "${ICNV_DIR}/README"     legal/libiconv.README
unix2dos -n "${IDN2_DIR}/AUTHORS"    legal/libidn2.AUTHORS.txt
unix2dos -n "${IDN2_DIR}/COPYING"    legal/libidn2.COPYING.txt
unix2dos -n "${IDN2_DIR}/README.md"  legal/libidn2.README.md
unix2dos -n "${NGH2_DIR}/AUTHORS"    legal/nghttp2.AUTHORS.txt
unix2dos -n "${NGH2_DIR}/COPYING"    legal/nghttp2.COPYING.txt
unix2dos -n "${NGH2_DIR}/README.rst" legal/nghttp2.README.rst
unix2dos -n "${OSSL_DIR}/AUTHORS"    legal/openssl.AUTHORS.txt
unix2dos -n "${OSSL_DIR}/LICENSE"    legal/openssl.LICENSE.txt
unix2dos -n "${OSSL_DIR}/README"     legal/openssl.README.txt
unix2dos -n "${SSH2_DIR}/COPYING"    legal/libssh2.COPYING.txt
unix2dos -n "${SSH2_DIR}/README"     legal/libssh2.README.txt
unix2dos -n "${ZLIB_DIR}/README"     legal/zlib.README.txt
unix2dos -n "${ZSTD_DIR}/LICENSE"    legal/zstandard.LICENSE.txt
unix2dos -n "${ZSTD_DIR}/README.md"  legal/zstandard.README.md
find "${OUT_DIR}" -type f -exec chmod 444 "{}" \;
readonly zfile="${BASE_DIR}/curl-win32.$(date +"%Y-%m-%d").zip"
rm -rf "${zfile}" && zip -v -r -9 "${zfile}" "."
chmod 444 "${zfile}"
popd

printf "\nCompleted.\n\n"
