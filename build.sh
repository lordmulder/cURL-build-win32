#!/bin/bash
#                              _   _ ____  _
#                          ___| | | |  _ \| |
#                         / __| | | | |_) | |
#                        | (__| |_| |  _ <| |___
#                         \___|\___/|_| \_\_____|

set -eo pipefail
trap 'read -p "Press any key..." x || true' EXIT

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cURL version
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly MY_VERSION=8.14.0

###############################################################################
# PREPARATION
###############################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Check bash version
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if [ -z "${BASH}" ] || [ ${BASH_VERSINFO[0]} -lt 5 ]; then
	echo 'This script requires BASH 5.x or newer !!!'
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Check environment
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly UNAME_SPEC="$(uname -so)"
if [[ "${UNAME_SPEC,,}" =~ ^mingw(32|64)(.*)msys$ ]]; then
	echo "Running on: ${UNAME_SPEC}"
else
	echo 'This script is supposed to run on MSYS2/Mingw-w64 !!!'
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Check C compiler
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly CC_TARGET="$(cc -dumpmachine)"
if [[ "${CC_TARGET,,}" =~ w64-mingw(32|64)$ ]]; then
	echo "Target arch: ${CC_TARGET}"
else
	if [[ -n "${CC_TARGET}" ]]; then
		echo 'This script is supposed to run on MSYS2/Mingw-w64 !!!'
	else
		echo 'Sorry, no working C compiler found !!!'
	fi
	exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Set up the compiler flags
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
case "${CC_TARGET}" in
  i686-*)
    readonly MY_CPU=x86
    readonly MY_MARCH=i586
    readonly MY_MTUNE=generic
    ;;
  x86_64-*)
    readonly MY_CPU=x64
    readonly MY_MARCH=x86-64
    readonly MY_MTUNE=znver3
    ;;
  *)
    echo "Unknown compiler arch detected !!!";
    exit 1
    ;;
esac

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Base directory
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly BASE_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if [ ! -d "${BASE_DIR}/build" ]; then
    echo 'Failed to find the "build" directory !!!';
    exit 1
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Mutex
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly SIGNATURE="$(date +"%s")-$$"
readonly LOCK_FILE="${BASE_DIR}/build/lockfile.${MY_CPU}"
readonly TEMP_FILE="$(mktemp /tmp/lockfile_XXXXX)"
printf "%s" "${SIGNATURE}" > "${TEMP_FILE}"
mv -n "${TEMP_FILE}" "${LOCK_FILE}"; rm -f "${TEMP_FILE}"
if [ "$(sed '/^$/d' "${LOCK_FILE}" | head -n1)" != "${SIGNATURE}" ] ; then
    echo 'Error: Build process is already in progress !!!'
    exit 1
else
    trap "{ rm -f \"${LOCK_FILE}\"; read -p \"Press any key...\" x; } || true" EXIT
fi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Logfile
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
exec &> >(tee "${BASE_DIR}/build/curl_build-${MY_CPU}.log")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Initialize paths
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly WORK_DIR="${BASE_DIR}/build/${MY_CPU}"
readonly PKGS_DIR="${WORK_DIR}/_pkgs"
readonly DEPS_DIR="${WORK_DIR}/_deps"
for i in {1..12}; do rm -rf "${WORK_DIR}" && break; done
mkdir -v "${WORK_DIR}"
mkdir -p "${PKGS_DIR}" "${DEPS_DIR}/bin" "${DEPS_DIR}/include" "${DEPS_DIR}/lib/pkgconfig" "${DEPS_DIR}/share"

###############################################################################
# DOWNLOAD SOURCES
###############################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Helper function
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function fetch_pkg () {
    if ! wget -4 --tries=8 --retry-connrefused -O "${2}" "${3}"; then
        return 1
    fi
    local checksum_computed="$(sha256sum -b "${2}" | head -n 1 | grep -Po '^[[:xdigit:]]+')"
    if ! [[ "${checksum_computed,,}" == "${1,,}" || "${1}" =~ ^z{64} ]]; then
        printf "Checksum mismatch detected!\n* Expected: %s\n* Computed: %s\n" "${1,,}" "${checksum_computed,,}"
        return  1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Download
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== download ====================\n\n"
fetch_pkg "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23" "${PKGS_DIR}/zlib.tar.gz"     https://zlib.net/zlib-1.3.1.tar.gz
fetch_pkg "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3" "${PKGS_DIR}/zstd.tar.gz"     https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz
fetch_pkg "e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff" "${PKGS_DIR}/brotli.tar.gz"   https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz
fetch_pkg "344d0a79f1a9b08029b0744e2cc401a43f9c90acd1044d09a530b4885a8e9fc0" "${PKGS_DIR}/openssl.tar.gz"  https://github.com/openssl/openssl/releases/download/openssl-3.5.0/openssl-3.5.0.tar.gz
fetch_pkg "c68e05989a93c002e3ba8df3baef0021c17099aa2123a9c096a5cc8e029caf95" "${PKGS_DIR}/rtmpdump.tar.gz" https://distfiles.macports.org/rtmpdump/f1b83c10d8beb43fcc70a6e88cf4325499f25857.tar.gz
fetch_pkg "3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8" "${PKGS_DIR}/libiconv.tar.gz" https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz
fetch_pkg "c918503d593d70daf4844d175a13d816afacb667c06fba1ec9dcd5002c1518b7" "${PKGS_DIR}/gettext.tar.gz"  https://ftp.gnu.org/pub/gnu/gettext/gettext-0.24.tar.gz
fetch_pkg "d9ec76cbe34db98eec3539fe2c899d26b0c837cb3eb466a56b0f109cabf658f7" "${PKGS_DIR}/libssh2.tar.gz"  https://www.libssh2.org/download/libssh2-1.11.1.tar.gz
fetch_pkg "8ca4f2a77ba7aac20aca3e3517a2c96cfcf7c6b064ab7d4a0809e7e4e9eb9914" "${PKGS_DIR}/nghttp2.tar.gz"  https://github.com/nghttp2/nghttp2/releases/download/v1.65.0/nghttp2-1.65.0.tar.gz
fetch_pkg "c86c8c6502141198ace1fb41e0293f035c6444ab1e057dc22bec8fe54f9991a2" "${PKGS_DIR}/nghttp3.tar.gz"  https://github.com/ngtcp2/nghttp3/releases/download/v1.10.1/nghttp3-1.10.1.tar.gz
fetch_pkg "a175a6a58313d5736256bf7978d20666f030632a5b6ba80c992d6475690633ea" "${PKGS_DIR}/ngtcp2.tar.gz"   https://github.com/ngtcp2/ngtcp2/releases/download/v1.13.0/ngtcp2-1.13.0.tar.gz
fetch_pkg "f557911bf6171621e1f72ff35f5b1825bb35b52ed45325dcdee931e5d3c0787a" "${PKGS_DIR}/libidn2.tar.gz"  https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz
fetch_pkg "1dcc9ceae8b128f3c0b3f654decd0e1e891afc6ff81098f227ef260449dae208" "${PKGS_DIR}/libpsl.tar.gz"   https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz
fetch_pkg "f1b553384dedbd87478449775546a358d6f5140c15cccc8fb574136fdc77329f" "${PKGS_DIR}/libgsasl.tar.gz" https://ftp.gnu.org/gnu/gsasl/libgsasl-1.10.0.tar.gz
fetch_pkg "5eba3ec2d898919a4b34cc89ace0068d9d09420b8643f265aebac59f8d126203" "${PKGS_DIR}/curl.tar.gz"     https://curl.se/download/curl-${MY_VERSION}.tar.gz
fetch_pkg "ab3ee3651977a4178a702b0b828a4ee7b2bbb9127235b0ab740e2e15974bf5db" "${PKGS_DIR}/cacert.pem"      https://curl.se/ca/cacert-2025-05-20.pem
fetch_pkg "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz" "${PKGS_DIR}/manpage.html"    https://curl.se/docs/manpage.html

###############################################################################
# BUILD DEPENDENCIES
###############################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# zlib
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== zlib ====================\n\n"
readonly ZLIB_DIR="${WORK_DIR}/zlib"
rm -rf "${ZLIB_DIR}" && mkdir "${ZLIB_DIR}"
tar -xvf "${PKGS_DIR}/zlib.tar.gz" --strip-components=1 -C "${ZLIB_DIR}"
pushd "${ZLIB_DIR}"
make -f win32/Makefile.gcc LOC="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501"
make -f win32/Makefile.gcc install BINARY_PATH="${DEPS_DIR}/include" INCLUDE_PATH="${DEPS_DIR}/include" LIBRARY_PATH="${DEPS_DIR}/lib"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Zstandard
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Zstandard ====================\n\n"
readonly ZSTD_DIR="${WORK_DIR}/zstd"
rm -rf "${ZSTD_DIR}" && mkdir "${ZSTD_DIR}"
tar -xvf "${PKGS_DIR}/zstd.tar.gz" --strip-components=1 -C "${ZSTD_DIR}" || true
pushd "${ZSTD_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" make lib V=1
cp -vf lib/libzstd.a "${DEPS_DIR}/lib"
cp -vf lib/zstd.h lib/zstd_errors.h lib/zdict.h "${DEPS_DIR}/include"
sed -e "s|@PREFIX@|${DEPS_DIR}|g" -e 's|@EXEC_PREFIX@|${prefix}|g' -e 's|@INCLUDEDIR@|${prefix}/include|g' -e 's|@LIBDIR@|${prefix}/lib|g' -e 's|@VERSION@|1.5.0|g' lib/libzstd.pc.in > "${DEPS_DIR}/lib/pkgconfig/libzstd.pc"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Brotli
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Brotli ====================\n\n"
readonly BROT_DIR="${WORK_DIR}/brotli"
rm -rf "${BROT_DIR}" && mkdir "${BROT_DIR}"
tar -xvf "${PKGS_DIR}/brotli.tar.gz" --strip-components=1 -C "${BROT_DIR}"
mkdir "${BROT_DIR}/out"
pushd "${BROT_DIR}/out"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib -static" cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=TRUE -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="${DEPS_DIR}" ..
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib -static" cmake --build . --config Release --target install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# OpenSSL / QuicTLS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== OpenSSL ====================\n\n"
readonly OSSL_DIR="${WORK_DIR}/openssl"
rm -rf "${OSSL_DIR}" && mkdir "${OSSL_DIR}"
tar -xvf "${PKGS_DIR}/openssl.tar.gz" --strip-components=1 -C "${OSSL_DIR}"
[[ "${MY_CPU}" == "x64" ]] && readonly ossl_flag="no-sse2" || readonly ossl_flag="386"
[[ "${MY_CPU}" == "x64" ]] && readonly ossl_mngw="mingw64" || readonly ossl_mngw="mingw"
pushd "${OSSL_DIR}"
./Configure no-hw no-shared no-engine no-capieng no-dso zlib ${ossl_flag} -static -march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I"${DEPS_DIR}/include" -L"${DEPS_DIR}/lib" --prefix="${DEPS_DIR}" --libdir="lib" ${ossl_mngw}
make build_libs && make install_dev
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# librtmp
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== librtmp ====================\n\n"
readonly RTMP_DIR="${WORK_DIR}/librtmp"
rm -rf "${RTMP_DIR}" && mkdir "${RTMP_DIR}"
tar -xvf "${PKGS_DIR}/rtmpdump.tar.gz" --strip-components=1 -C "${RTMP_DIR}"
pushd "${RTMP_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/librtmp_openssl.diff"
make SYS=mingw SHARED= prefix="${DEPS_DIR}" XCFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" XLDFLAGS="-L${DEPS_DIR}/lib" XLIBS="-lws2_32 -lcrypt32"
make SYS=mingw SHARED= prefix="${DEPS_DIR}" install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libiconv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libiconv ====================\n\n"
readonly ICNV_DIR="${WORK_DIR}/libiconv"
rm -rf "${ICNV_DIR}" && mkdir "${ICNV_DIR}"
tar -xvf "${PKGS_DIR}/libiconv.tar.gz" --strip-components=1 -C "${ICNV_DIR}"
pushd "${ICNV_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" ./configure --prefix="${DEPS_DIR}" --disable-rpath --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# gettext
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== gettext ====================\n\n"
readonly GTXT_DIR="${WORK_DIR}/gettext"
rm -rf "${GTXT_DIR}" && mkdir "${GTXT_DIR}"
tar -xvf "${PKGS_DIR}/gettext.tar.gz" --strip-components=1 -C "${GTXT_DIR}"
pushd "${GTXT_DIR}/gettext-runtime"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" ./configure --prefix="${DEPS_DIR}" --disable-shared --disable-libasprintf --without-emacs --disable-java --disable-native-java --disable-csharp --disable-openmp
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libssh2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libssh2 ====================\n\n"
readonly SSH2_DIR="${WORK_DIR}/libssh2"
rm -rf "${SSH2_DIR}" && mkdir "${SSH2_DIR}"
tar -xvf "${PKGS_DIR}/libssh2.tar.gz" --strip-components=1 -C "${SSH2_DIR}"
pushd "${SSH2_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/ssh2_session.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" ./configure --prefix="${DEPS_DIR}" --disable-examples-build --disable-shared --with-libz
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# nghttp2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== nghttp2 ====================\n\n"
readonly NGH2_DIR="${WORK_DIR}/nghttp2"
rm -rf "${NGH2_DIR}" && mkdir "${NGH2_DIR}"
tar -xvf "${PKGS_DIR}/nghttp2.tar.gz" --strip-components=1 -C "${NGH2_DIR}"
pushd "${NGH2_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/nghttp2_time.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" OPENSSL_CFLAGS="-I${DEPS_DIR}/include" OPENSSL_LIBS="-L${DEPS_DIR}/lib -lssl -lcrypto" ZLIB_CFLAGS="-I${DEPS_DIR}/include" ZLIB_LIBS="-L${DEPS_DIR}/lib -lz" ./configure --prefix="${DEPS_DIR}" --enable-lib-only --disable-threads --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# nghttp3
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== nghttp3 ====================\n\n"
readonly NGH3_DIR="${WORK_DIR}/nghttp3"
rm -rf "${NGH3_DIR}" && mkdir "${NGH3_DIR}"
tar -xvf "${PKGS_DIR}/nghttp3.tar.gz" --strip-components=1 -C "${NGH3_DIR}"
pushd "${NGH3_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" OPENSSL_CFLAGS="-I${DEPS_DIR}/include" OPENSSL_LIBS="-L${DEPS_DIR}/lib -lssl -lcrypto" ZLIB_CFLAGS="-I${DEPS_DIR}/include" ZLIB_LIBS="-L${DEPS_DIR}/lib -lz" ./configure --prefix="${DEPS_DIR}" --enable-lib-only --disable-threads --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ngtcp2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== ngtcp2 ====================\n\n"
readonly TCP2_DIR="${WORK_DIR}/ngtcp2"
rm -rf "${TCP2_DIR}" && mkdir "${TCP2_DIR}"
tar -xvf "${PKGS_DIR}/ngtcp2.tar.gz" --strip-components=1 -C "${TCP2_DIR}"
pushd "${TCP2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" OPENSSL_CFLAGS="-I${DEPS_DIR}/include" OPENSSL_LIBS="-L${DEPS_DIR}/lib -lssl -lcrypto -lws2_32 -lz -lcrypt32" ZLIB_CFLAGS="-I${DEPS_DIR}/include" ZLIB_LIBS="-L${DEPS_DIR}/lib -lz" ./configure --prefix="${DEPS_DIR}" --enable-lib-only --with-openssl --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libidn2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libidn2 ====================\n\n"
readonly IDN2_DIR="${WORK_DIR}/libidn2"
rm -rf "${IDN2_DIR}" && mkdir "${IDN2_DIR}"
tar -xvf "${PKGS_DIR}/libidn2.tar.gz" --strip-components=1 -C "${IDN2_DIR}"
pushd "${IDN2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" ./configure --prefix="${DEPS_DIR}" --disable-shared --disable-doc --without-libiconv-prefix --without-libunistring-prefix --disable-valgrind-tests
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libpsl
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libpsl ====================\n\n"
readonly LPSL_DIR="${WORK_DIR}/libpsl"
rm -rf "${LPSL_DIR}" && mkdir "${LPSL_DIR}"
tar -xvf "${PKGS_DIR}/libpsl.tar.gz" --strip-components=1 -C "${LPSL_DIR}"
pushd "${LPSL_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include" LDFLAGS="-L${DEPS_DIR}/lib" ./configure --prefix="${DEPS_DIR}" --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libgsasl
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libgsasl ====================\n\n"
readonly SASL_DIR="${WORK_DIR}/libgsasl"
rm -rf "${SASL_DIR}" && mkdir "${SASL_DIR}"
tar -xvf "${PKGS_DIR}/libgsasl.tar.gz" --strip-components=1 -C "${SASL_DIR}"
pushd "${SASL_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${DEPS_DIR}/include -Wno-error=int-conversion" LDFLAGS="-L${DEPS_DIR}/lib" ./configure --prefix="${DEPS_DIR}" --disable-shared --disable-valgrind-tests --disable-obsolete -without-libintl-prefix
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cURL (full)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== cURL (full) ====================\n\n"
readonly CURL_DIR="${WORK_DIR}/curl.full"
rm -rf "${CURL_DIR}" && mkdir "${CURL_DIR}"
tar -xvf "${PKGS_DIR}/curl.tar.gz" --strip-components=1 -C "${CURL_DIR}"
pushd "${CURL_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/curl_getenv.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_threads.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_doswin.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_getparam.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_operate.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_parsecfg.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_util.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I${DEPS_DIR}/include" CPPFLAGS="-DNDEBUG -D_WIN32_WINNT=0x0501 -DNGHTTP2_STATICLIB -DNGHTTP3_STATICLIB -DNGTCP2_STATICLIB -DUNICODE -D_UNICODE" LDFLAGS="-mconsole -Wl,--trace -static -no-pthread -L${DEPS_DIR}/lib" LIBS="-liconv -lcrypt32 -lwinmm -lbrotlicommon" PKG_CONFIG_PATH="${DEPS_DIR}/lib/pkgconfig" ./configure --enable-static --disable-shared --enable-windows-unicode --disable-libcurl-option --disable-openssl-auto-load-config --enable-ca-search-safe --with-zlib --with-openssl --with-libidn2 --without-ca-bundle --with-zstd --with-brotli --with-librtmp --with-libssh2 --with-nghttp2="${DEPS_DIR}" --with-ngtcp2="${DEPS_DIR}" --with-nghttp3="${DEPS_DIR}"
make V=1
strip -s src/curl.exe
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cURL (slim)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== cURL (slim) ====================\n\n"
readonly SLIM_DIR="${WORK_DIR}/curl.slim"
rm -rf "${SLIM_DIR}" && mkdir "${SLIM_DIR}"
tar -xvf "${PKGS_DIR}/curl.tar.gz" --strip-components=1 -C "${SLIM_DIR}"
pushd "${SLIM_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/curl_getenv.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_threads.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_doswin.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_getparam.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_operate.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_parsecfg.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_util.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I${DEPS_DIR}/include" CPPFLAGS="-DNDEBUG -D_WIN32_WINNT=0x0501 -DUNICODE -D_UNICODE" LDFLAGS="-mconsole -Wl,--trace -static -no-pthread -L${DEPS_DIR}/lib" LIBS="-liconv -lcrypt32 -lwinmm" PKG_CONFIG_PATH="${DEPS_DIR}/lib/pkgconfig" ./configure --enable-static --disable-shared --enable-windows-unicode --disable-libcurl-option --disable-openssl-auto-load-config --enable-ca-search-safe --with-zlib --with-openssl --with-libidn2 --without-ca-bundle --without-zstd --without-brotli --without-librtmp --without-libssh2 --without-nghttp2 --without-ngtcp2 --without-nghttp3 --without-libgsasl
make V=1
strip -s src/curl.exe
popd

###############################################################################
# CREATE RELEASE FILES
###############################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Output (full)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Output (full) ====================\n\n"
OUT_DIR="${WORK_DIR}/_bin/full"
rm -rf "${OUT_DIR}" && mkdir -p "${OUT_DIR}"
pushd "${OUT_DIR}"
cp -vf "${CURL_DIR}/src/curl.exe" curl.exe
cp -vf "${PKGS_DIR}/cacert.pem"   curl-ca-bundle.crt
cp -vf "${PKGS_DIR}/manpage.html" manpage.html
sed -n "/Configured to build curl\/libcurl:$/,/^[[:space:]]*Features:/p" "${CURL_DIR}/config.log" | sed -r "s/configure:[[:digit:]]+://" | sed -r "s/^[[:blank:]]*//" | unix2dos > config.log
mkdir -p "${OUT_DIR}/legal"
unix2dos -n "${BROT_DIR}/LICENSE"     "legal/brotli.LICENSE.txt"
unix2dos -n "${BROT_DIR}/README.md"   "legal/brotli.README.md"
unix2dos -n "${CURL_DIR}/CHANGES.md"  "legal/curl.CHANGES.txt"
unix2dos -n "${CURL_DIR}/COPYING"     "legal/curl.COPYING.txt"
unix2dos -n "${CURL_DIR}/README"      "legal/curl.README.txt"
unix2dos -n "${GTXT_DIR}/AUTHORS"     "legal/gettext.AUTHORS.txt"
unix2dos -n "${GTXT_DIR}/COPYING"     "legal/gettext.COPYING.txt"
unix2dos -n "${GTXT_DIR}/README"      "legal/gettext.README.txt"
unix2dos -n "${ICNV_DIR}/AUTHORS"     "legal/libiconv.AUTHORS.txt"
unix2dos -n "${ICNV_DIR}/COPYING"     "legal/libiconv.COPYING.txt"
unix2dos -n "${ICNV_DIR}/README"      "legal/libiconv.README"
unix2dos -n "${IDN2_DIR}/AUTHORS"     "legal/libidn2.AUTHORS.txt"
unix2dos -n "${IDN2_DIR}/COPYING"     "legal/libidn2.COPYING.txt"
unix2dos -n "${IDN2_DIR}/README.md"   "legal/libidn2.README.md"
unix2dos -n "${LPSL_DIR}/AUTHORS"     "legal/libpsl.AUTHORS.txt"
unix2dos -n "${LPSL_DIR}/COPYING"     "legal/libpsl.COPYING.txt"
unix2dos -n "${NGH2_DIR}/AUTHORS"     "legal/nghttp2.AUTHORS.txt"
unix2dos -n "${NGH2_DIR}/COPYING"     "legal/nghttp2.COPYING.txt"
unix2dos -n "${NGH2_DIR}/README.rst"  "legal/nghttp2.README.rst"
unix2dos -n "${NGH3_DIR}/COPYING"     "legal/nghttp3.COPYING.txt"
unix2dos -n "${NGH3_DIR}/README.rst"  "legal/nghttp3.README.rst"
unix2dos -n "${TCP2_DIR}/COPYING"     "legal/ngtcp2.COPYING.txt"
unix2dos -n "${TCP2_DIR}/README.rst"  "legal/ngtcp2.README.rst"
unix2dos -n "${OSSL_DIR}/AUTHORS.md"  "legal/openssl.AUTHORS.md"
unix2dos -n "${OSSL_DIR}/LICENSE.txt" "legal/openssl.LICENSE.txt"
unix2dos -n "${OSSL_DIR}/README.md"   "legal/openssl.README.md"
unix2dos -n "${RTMP_DIR}/COPYING"     "legal/librtmp.COPYING.txt"
unix2dos -n "${RTMP_DIR}/README"      "legal/librtmp.README.txt"
unix2dos -n "${SASL_DIR}/AUTHORS"     "legal/libgsasl.AUTHORS.txt"
unix2dos -n "${SASL_DIR}/COPYING"     "legal/libgsasl.COPYING.txt"
unix2dos -n "${SASL_DIR}/README"      "legal/libgsasl.README.txt"
unix2dos -n "${SSH2_DIR}/COPYING"     "legal/libssh2.COPYING.txt"
unix2dos -n "${SSH2_DIR}/README"      "legal/libssh2.README.txt"
unix2dos -n "${ZLIB_DIR}/README"      "legal/zlib.README.txt"
unix2dos -n "${ZSTD_DIR}/LICENSE"     "legal/zstandard.LICENSE.txt"
unix2dos -n "${ZSTD_DIR}/README.md"   "legal/zstandard.README.md"
mkdir -p "${OUT_DIR}/patch"
cp -vf "${BASE_DIR}/patch/"*.diff "${OUT_DIR}/patch"
find "${OUT_DIR}" -type f -exec chmod 444 "{}" \;
zfile="${BASE_DIR}/build/curl-${MY_VERSION}-windows-${MY_CPU}-full.$(date +"%Y-%m-%d").zip"
rm -rf "${zfile}" && zip -v -r -9 "${zfile}" "."
chmod 444 "${zfile}"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Output (slim)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Output (slim) ====================\n\n"
OUT_DIR="${WORK_DIR}/_bin/slim"
rm -rf "${OUT_DIR}" && mkdir -p "${OUT_DIR}"
pushd "${OUT_DIR}"
cp -vf "${SLIM_DIR}/src/curl.exe" curl.exe
cp -vf "${PKGS_DIR}/cacert.pem"   curl-ca-bundle.crt
cp -vf "${PKGS_DIR}/manpage.html" manpage.html
sed -n "/Configured to build curl\/libcurl:$/,/^[[:space:]]*Features:/p" "${SLIM_DIR}/config.log" | sed -r "s/configure:[[:digit:]]+://" | sed -r "s/^[[:blank:]]*//" | unix2dos > config.log
mkdir -p "${OUT_DIR}/legal"
unix2dos -n "${SLIM_DIR}/CHANGES.md"  "legal/curl.CHANGES.txt"
unix2dos -n "${SLIM_DIR}/COPYING"     "legal/curl.COPYING.txt"
unix2dos -n "${SLIM_DIR}/README"      "legal/curl.README.txt"
unix2dos -n "${GTXT_DIR}/AUTHORS"     "legal/gettext.AUTHORS.txt"
unix2dos -n "${GTXT_DIR}/COPYING"     "legal/gettext.COPYING.txt"
unix2dos -n "${GTXT_DIR}/README"      "legal/gettext.README.txt"
unix2dos -n "${ICNV_DIR}/AUTHORS"     "legal/libiconv.AUTHORS.txt"
unix2dos -n "${ICNV_DIR}/COPYING"     "legal/libiconv.COPYING.txt"
unix2dos -n "${ICNV_DIR}/README"      "legal/libiconv.README"
unix2dos -n "${IDN2_DIR}/AUTHORS"     "legal/libidn2.AUTHORS.txt"
unix2dos -n "${IDN2_DIR}/COPYING"     "legal/libidn2.COPYING.txt"
unix2dos -n "${IDN2_DIR}/README.md"   "legal/libidn2.README.md"
unix2dos -n "${LPSL_DIR}/AUTHORS"     "legal/libpsl.AUTHORS.txt"
unix2dos -n "${LPSL_DIR}/COPYING"     "legal/libpsl.COPYING.txt"
unix2dos -n "${OSSL_DIR}/AUTHORS.md"  "legal/openssl.AUTHORS.md"
unix2dos -n "${OSSL_DIR}/LICENSE.txt" "legal/openssl.LICENSE.txt"
unix2dos -n "${OSSL_DIR}/README.md"   "legal/openssl.README.md"
unix2dos -n "${ZLIB_DIR}/README"      "legal/zlib.README.txt"
mkdir -p "${OUT_DIR}/patch"
cp -vf "${BASE_DIR}/patch/"*.diff "${OUT_DIR}/patch"
find "${OUT_DIR}" -type f -exec chmod 444 "{}" \;
zfile="${BASE_DIR}/build/curl-${MY_VERSION}-windows-${MY_CPU}-slim.$(date +"%Y-%m-%d").zip"
rm -rf "${zfile}" && zip -v -r -9 "${zfile}" "."
chmod 444 "${zfile}"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Complete
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\nCompleted.\n\n"
