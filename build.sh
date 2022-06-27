#!/bin/bash
#                              _   _ ____  _
#                          ___| | | |  _ \| |
#                         / __| | | | |_) | |
#                        | (__| |_| |  _ <| |___
#                         \___|\___/|_| \_\_____|

set -e
trap 'read -p "Press any key..." x' EXIT

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Set up compiler
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
case "$(cc -dumpmachine)" in
  i686-*)
    readonly MY_CPU=x86
    readonly MY_MARCH=i486
    readonly MY_MTUNE=intel
    ;;
  x86_64-*)
    readonly MY_CPU=x64
    readonly MY_MARCH=x86-64
    readonly MY_MTUNE=corei7
    ;;
  *)
    echo "Unknown compiler detected!";
    exit 1
    ;;
esac

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Initialize paths
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
readonly BASE_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
readonly LIBS_DIR="${BASE_DIR}/.local/${MY_CPU}"
find "${BASE_DIR}" -maxdepth 1 -type d -name "*-${MY_CPU}" -exec rm -rf "{}" \;
rm -rf "${LIBS_DIR}" && mkdir -p "${LIBS_DIR}/.pkg" "${LIBS_DIR}/bin" "${LIBS_DIR}/include" "${LIBS_DIR}/lib/pkgconfig" "${LIBS_DIR}/share"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Download
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
wget -4 -O "${LIBS_DIR}/.pkg/zlib.tar.gz"     https://zlib.net/zlib-1.2.12.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/zstd.tar.gz"     https://github.com/facebook/zstd/releases/download/v1.5.2/zstd-1.5.2.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/brotli.tar.gz"   https://github.com/google/brotli/archive/v1.0.9/brotli-1.0.9.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/openssl.tar.gz"  https://github.com/quictls/openssl/archive/refs/heads/OpenSSL_1_1_1p+quic.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/rtmpdump.tar.gz" http://git.ffmpeg.org/gitweb/rtmpdump.git/snapshot/f1b83c10d8beb43fcc70a6e88cf4325499f25857.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/libiconv.tar.gz" https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/gettext.tar.gz"  https://ftp.gnu.org/pub/gnu/gettext/gettext-0.21.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/libssh2.tar.gz"  https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/nghttp2.tar.gz"  https://github.com/nghttp2/nghttp2/releases/download/v1.47.0/nghttp2-1.47.0.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/nghttp3.tar.gz"  https://github.com/ngtcp2/nghttp3/releases/download/v0.5.0/nghttp3-0.5.0.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/ngtcp2.tar.gz"   https://github.com/ngtcp2/ngtcp2/releases/download/v0.6.0/ngtcp2-0.6.0.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/libidn2.tar.gz"  https://ftp.gnu.org/gnu/libidn/libidn2-2.3.2.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/libgsasl.tar.gz" https://ftp.gnu.org/gnu/gsasl/libgsasl-1.10.0.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/curl.tar.gz"     https://curl.se/download/curl-7.84.0.tar.gz
wget -4 -O "${LIBS_DIR}/.pkg/cacert.pem"      https://curl.se/ca/cacert.pem
wget -4 -O "${LIBS_DIR}/.pkg/manpage.html"    https://curl.se/docs/manpage.html

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# zlib
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== zlib ====================\n\n"
readonly ZLIB_DIR="${BASE_DIR}/zlib-${MY_CPU}"
rm -rf "${ZLIB_DIR}" && mkdir "${ZLIB_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/zlib.tar.gz" --strip-components=1 -C "${ZLIB_DIR}"
pushd "${ZLIB_DIR}"
make -f win32/Makefile.gcc LOC="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501"
make -f win32/Makefile.gcc install BINARY_PATH="${LIBS_DIR}/include" INCLUDE_PATH="${LIBS_DIR}/include" LIBRARY_PATH="${LIBS_DIR}/lib"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Zstandard
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Zstandard ====================\n\n"
readonly ZSTD_DIR="${BASE_DIR}/zstd-${MY_CPU}"
rm -rf "${ZSTD_DIR}" && mkdir "${ZSTD_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/zstd.tar.gz" --strip-components=1 -C "${ZSTD_DIR}"
pushd "${ZSTD_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" make lib
cp -vf lib/libzstd.a "${LIBS_DIR}/lib"
cp -vf lib/zstd.h lib/zstd_errors.h lib/zdict.h "${LIBS_DIR}/include"
sed -e "s|@PREFIX@|${LIBS_DIR}|g" -e 's|@EXEC_PREFIX@|${prefix}|g' -e 's|@INCLUDEDIR@|${prefix}/include|g' -e 's|@LIBDIR@|${prefix}/lib|g' -e 's|@VERSION@|1.5.0|g' lib/libzstd.pc.in > "${LIBS_DIR}/lib/pkgconfig/libzstd.pc"
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Brotli
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Brotli ====================\n\n"
readonly BROT_DIR="${BASE_DIR}/brotli-${MY_CPU}"
rm -rf "${BROT_DIR}" && mkdir "${BROT_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/brotli.tar.gz" --strip-components=1 -C "${BROT_DIR}"
pushd "${BROT_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" make lib
mkdir -p "${LIBS_DIR}/include/brotli"
cp -vf c/include/brotli/*.h "${LIBS_DIR}/include/brotli"
for fname in scripts/*.pc.in; do
  cp -vf libbrotli.a "${LIBS_DIR}/lib/$(basename "${fname}" .pc.in).a"
  sed -e "s|@prefix@|${LIBS_DIR}|g" -e 's|@exec_prefix@|${prefix}|g' -e 's|@includedir@|${prefix}/include|g' -e 's|@libdir@|${prefix}/lib|g' -e 's|@PACKAGE_VERSION@|1.0.9|g' ${fname} > "${LIBS_DIR}/lib/pkgconfig/$(basename "${fname}" .in)"
done
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# OpenSSL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== OpenSSL ====================\n\n"
readonly OSSL_DIR="${BASE_DIR}/openssl-${MY_CPU}"
rm -rf "${OSSL_DIR}" && mkdir "${OSSL_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/openssl.tar.gz" --strip-components=1 -C "${OSSL_DIR}"
[[ "${MY_CPU}" == "x64" ]] && readonly ossl_flag="no-sse2" || readonly ossl_flag="386"
[[ "${MY_CPU}" == "x64" ]] && readonly ossl_mngw="mingw64" || readonly ossl_mngw="mingw"
pushd "${OSSL_DIR}"
./Configure no-hw no-shared no-engine no-capieng no-dso zlib ${ossl_flag} -static -march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I"${LIBS_DIR}/include" -L"${LIBS_DIR}/lib" --prefix="${LIBS_DIR}" ${ossl_mngw}
make build_libs && make install_dev
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# librtmp
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== librtmp ====================\n\n"
readonly RTMP_DIR="${BASE_DIR}/librtmp-${MY_CPU}"
rm -rf "${RTMP_DIR}" && mkdir "${RTMP_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/rtmpdump.tar.gz" --strip-components=1 -C "${RTMP_DIR}"
pushd "${RTMP_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/librtmp_openssl.diff"
make SYS=mingw SHARED= prefix="${LIBS_DIR}" XCFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" XLDFLAGS="-L${LIBS_DIR}/lib" XLIBS="-lws2_32"
make SYS=mingw SHARED= prefix="${LIBS_DIR}" install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libiconv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libiconv ====================\n\n"
readonly ICNV_DIR="${BASE_DIR}/libiconv-${MY_CPU}"
rm -rf "${ICNV_DIR}" && mkdir "${ICNV_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/libiconv.tar.gz" --strip-components=1 -C "${ICNV_DIR}"
pushd "${ICNV_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" ./configure --prefix="${LIBS_DIR}" --disable-rpath --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# gettext
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== gettext ====================\n\n"
readonly GTXT_DIR="${BASE_DIR}/gettext-${MY_CPU}"
rm -rf "${GTXT_DIR}" && mkdir "${GTXT_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/gettext.tar.gz" --strip-components=1 -C "${GTXT_DIR}"
pushd "${GTXT_DIR}/gettext-runtime"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" ./configure --prefix="${LIBS_DIR}" --disable-shared --disable-libasprintf --without-emacs --disable-java --disable-native-java --disable-csharp --disable-openmp
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libssh2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libssh2 ====================\n\n"
readonly SSH2_DIR="${BASE_DIR}/libssh2-${MY_CPU}"
rm -rf "${SSH2_DIR}" && mkdir "${SSH2_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/libssh2.tar.gz" --strip-components=1 -C "${SSH2_DIR}"
pushd "${SSH2_DIR}"
patch -p1 -b < "${BASE_DIR}/patch/ssh2_session.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" ./configure --prefix="${LIBS_DIR}" --disable-examples-build --disable-shared --with-libz
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# nghttp2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== nghttp2 ====================\n\n"
readonly NGH2_DIR="${BASE_DIR}/nghttp2-${MY_CPU}"
rm -rf "${NGH2_DIR}" && mkdir "${NGH2_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/nghttp2.tar.gz" --strip-components=1 -C "${NGH2_DIR}"
pushd "${NGH2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" OPENSSL_CFLAGS="-I${LIBS_DIR}/include" OPENSSL_LIBS="-L${LIBS_DIR}/lib -lssl -lcrypto" ZLIB_CFLAGS="-I${LIBS_DIR}/include" ZLIB_LIBS="-L${LIBS_DIR}/lib -lz" ./configure --prefix="${LIBS_DIR}" --enable-lib-only --disable-threads --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# nghttp3
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== nghttp3 ====================\n\n"
readonly NGH3_DIR="${BASE_DIR}/nghttp3-${MY_CPU}"
rm -rf "${NGH3_DIR}" && mkdir "${NGH3_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/nghttp3.tar.gz" --strip-components=1 -C "${NGH3_DIR}"
pushd "${NGH3_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" OPENSSL_CFLAGS="-I${LIBS_DIR}/include" OPENSSL_LIBS="-L${LIBS_DIR}/lib -lssl -lcrypto" ZLIB_CFLAGS="-I${LIBS_DIR}/include" ZLIB_LIBS="-L${LIBS_DIR}/lib -lz" ./configure --prefix="${LIBS_DIR}" --enable-lib-only --disable-threads --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ngtcp2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== ngtcp2 ====================\n\n"
readonly TCP2_DIR="${BASE_DIR}/ngtcp2-${MY_CPU}"
rm -rf "${TCP2_DIR}" && mkdir "${TCP2_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/ngtcp2.tar.gz" --strip-components=1 -C "${TCP2_DIR}"
pushd "${TCP2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" OPENSSL_CFLAGS="-I${LIBS_DIR}/include" OPENSSL_LIBS="-L${LIBS_DIR}/lib -lssl -lcrypto -lws2_32 -lz" ZLIB_CFLAGS="-I${LIBS_DIR}/include" ZLIB_LIBS="-L${LIBS_DIR}/lib -lz" ./configure --prefix="${LIBS_DIR}" --enable-lib-only --with-openssl --disable-shared
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libidn2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libidn2 ====================\n\n"
readonly IDN2_DIR="${BASE_DIR}/libidn2-${MY_CPU}"
rm -rf "${IDN2_DIR}" && mkdir "${IDN2_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/libidn2.tar.gz" --strip-components=1 -C "${IDN2_DIR}"
pushd "${IDN2_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" ./configure --prefix="${LIBS_DIR}" --disable-shared --disable-doc --without-libiconv-prefix --without-libunistring-prefix --disable-valgrind-tests
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# libgsasl
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== libgsasl ====================\n\n"
readonly SASL_DIR="${BASE_DIR}/libgsasl-${MY_CPU}"
rm -rf "${SASL_DIR}" && mkdir "${SASL_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/libgsasl.tar.gz" --strip-components=1 -C "${SASL_DIR}"
pushd "${SASL_DIR}"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -DNDEBUG -D_WIN32_WINNT=0x0501 -I${LIBS_DIR}/include" LDFLAGS="-L${LIBS_DIR}/lib" ./configure --prefix="${LIBS_DIR}" --disable-shared --disable-valgrind-tests --disable-obsolete -without-libintl-prefix
make && make install
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# cURL
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== cURL ====================\n\n"
readonly CURL_DIR="${BASE_DIR}/curl-${MY_CPU}"
rm -rf "${CURL_DIR}" && mkdir "${CURL_DIR}"
tar -xvf "${LIBS_DIR}/.pkg/curl.tar.gz" --strip-components=1 -C "${CURL_DIR}"
pushd "${CURL_DIR}"
sed -i -E 's/\bmain[[:space:]]*\(([^\(\)]*)\)/wmain(\1)/g' configure
patch -p1 -b < "${BASE_DIR}/patch/curl_getenv.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_threads.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_doswin.diff"
patch -p1 -b < "${BASE_DIR}/patch/curl_tool_parsecfg.diff"
CFLAGS="-march=${MY_MARCH} -mtune=${MY_MTUNE} -I${LIBS_DIR}/include" CPPFLAGS="-DNDEBUG -D_WIN32_WINNT=0x0501 -DNGHTTP2_STATICLIB -DNGHTTP3_STATICLIB -DNGTCP2_STATICLIB -DUNICODE -D_UNICODE" LDFLAGS="-municode -mconsole -Wl,--trace -static -no-pthread -L${LIBS_DIR}/lib" LIBS="-liconv -lcrypt32 -lwinmm" PKG_CONFIG_PATH="${LIBS_DIR}/lib/pkgconfig" ./configure --enable-static --disable-shared --disable-pthreads --disable-libcurl-option --disable-openssl-auto-load-config --with-zlib --with-zstd --with-brotli --with-openssl --with-librtmp --with-libssh2 --with-nghttp2="${LIBS_DIR}" --with-ngtcp2="${LIBS_DIR}" --with-nghttp3="${LIBS_DIR}" --with-libidn2 --with-gsasl --without-ca-bundle
make V=1
strip -s src/curl.exe
popd

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Output
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
printf "\n==================== Output ====================\n\n"
readonly OUT_DIR="${BASE_DIR}/.bin/${MY_CPU}"
rm -rf "${OUT_DIR}" && mkdir -p "${OUT_DIR}"
pushd "${OUT_DIR}"
cp -vf "${CURL_DIR}/src/curl.exe"      curl.exe
cp -vf "${LIBS_DIR}/.pkg/cacert.pem"   curl-ca-bundle.crt
cp -vf "${LIBS_DIR}/.pkg/manpage.html" manpage.html
sed -n "/Configured to build curl\/libcurl:$/,/^[[:space:]]*Features:/p" "${CURL_DIR}/config.log" | sed -r "s/configure:[[:digit:]]+://" | sed -r "s/^[[:blank:]]*//" | unix2dos > config.log
mkdir -p "${OUT_DIR}/legal"
unix2dos -n "${BROT_DIR}/LICENSE"    legal/brotli.LICENSE.txt
unix2dos -n "${BROT_DIR}/README.md"  legal/brotli.README.md
unix2dos -n "${CURL_DIR}/CHANGES"    legal/curl.CHANGES.txt
unix2dos -n "${CURL_DIR}/COPYING"    legal/curl.COPYING.txt
unix2dos -n "${CURL_DIR}/README"     legal/curl.README.txt
unix2dos -n "${GTXT_DIR}/AUTHORS"    legal/gettext.AUTHORS.txt
unix2dos -n "${GTXT_DIR}/COPYING"    legal/gettext.COPYING.txt
unix2dos -n "${GTXT_DIR}/README"     legal/gettext.README.txt
unix2dos -n "${ICNV_DIR}/AUTHORS"    legal/libiconv.AUTHORS.txt
unix2dos -n "${ICNV_DIR}/COPYING"    legal/libiconv.COPYING.txt
unix2dos -n "${ICNV_DIR}/README"     legal/libiconv.README
unix2dos -n "${IDN2_DIR}/AUTHORS"    legal/libidn2.AUTHORS.txt
unix2dos -n "${IDN2_DIR}/COPYING"    legal/libidn2.COPYING.txt
unix2dos -n "${IDN2_DIR}/README.md"  legal/libidn2.README.md
unix2dos -n "${NGH2_DIR}/AUTHORS"    legal/nghttp2.AUTHORS.txt
unix2dos -n "${NGH2_DIR}/COPYING"    legal/nghttp2.COPYING.txt
unix2dos -n "${NGH2_DIR}/README.rst" legal/nghttp2.README.rst
unix2dos -n "${NGH3_DIR}/COPYING"    legal/nghttp3.COPYING.txt
unix2dos -n "${NGH3_DIR}/README.rst" legal/nghttp3.README.rst
unix2dos -n "${TCP2_DIR}/COPYING"    legal/ngtcp2.COPYING.txt
unix2dos -n "${TCP2_DIR}/README.rst" legal/ngtcp2.README.rst
unix2dos -n "${OSSL_DIR}/AUTHORS"    legal/openssl.AUTHORS.txt
unix2dos -n "${OSSL_DIR}/LICENSE"    legal/openssl.LICENSE.txt
unix2dos -n "${OSSL_DIR}/README.md"  legal/openssl.README.md
unix2dos -n "${RTMP_DIR}/COPYING"    legal/librtmp.COPYING.txt
unix2dos -n "${RTMP_DIR}/README"     legal/librtmp.README.txt
unix2dos -n "${SASL_DIR}/AUTHORS"    legal/libgsasl.AUTHORS.txt
unix2dos -n "${SASL_DIR}/COPYING"    legal/libgsasl.COPYING.txt
unix2dos -n "${SASL_DIR}/README"     legal/libgsasl.README.txt
unix2dos -n "${SSH2_DIR}/COPYING"    legal/libssh2.COPYING.txt
unix2dos -n "${SSH2_DIR}/README"     legal/libssh2.README.txt
unix2dos -n "${ZLIB_DIR}/README"     legal/zlib.README.txt
unix2dos -n "${ZSTD_DIR}/LICENSE"    legal/zstandard.LICENSE.txt
unix2dos -n "${ZSTD_DIR}/README.md"  legal/zstandard.README.md
mkdir -p "${OUT_DIR}/patch"
cp -vf "${BASE_DIR}/patch/"*.diff "${OUT_DIR}/patch"
find "${OUT_DIR}" -type f -exec chmod 444 "{}" \;
readonly zfile="${BASE_DIR}/curl-windows-${MY_CPU}.$(date +"%Y-%m-%d").zip"
rm -rf "${zfile}" && zip -v -r -9 "${zfile}" "."
chmod 444 "${zfile}"
popd

printf "\nCompleted.\n\n"
