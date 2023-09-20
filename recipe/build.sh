#!/bin/bash
set -ex

# Hints:
# http://boost.2283326.n4.nabble.com/how-to-build-boost-with-bzip2-in-non-standard-location-td2661155.html
# http://www.gentoo.org/proj/en/base/amd64/howtos/?part=1&chap=3
# http://www.boost.org/doc/libs/1_55_0/doc/html/bbv2/reference.html

# Hints for OSX:
# http://stackoverflow.com/questions/20108407/how-do-i-compile-boost-for-os-x-64b-platforms-with-stdlibc

INCLUDE_PATH="${PREFIX}/include"
LIBRARY_PATH="${PREFIX}/lib"

# Always build PIC code for enable static linking into other shared libraries
CXXFLAGS="${CXXFLAGS} -fPIC"

if [[ "${target_platform}" == osx* ]]; then
    TOOLSET=clang
elif [[ "${target_platform}" == linux* ]]; then
    TOOLSET=gcc
fi

# http://www.boost.org/build/doc/html/bbv2/tasks/crosscompile.html
cat <<EOF > ${SRC_DIR}/tools/build/src/site-config.jam
using ${TOOLSET} : : ${CXX} ;
EOF

LINKFLAGS="${LINKFLAGS} -L${LIBRARY_PATH}"

CXXFLAGS="$(echo ${CXXFLAGS} | sed 's/ -march=[^ ]*//g' | sed 's/ -mcpu=[^ ]*//g' |sed 's/ -mtune=[^ ]*//g')" \
CFLAGS="$(echo ${CFLAGS} | sed 's/ -march=[^ ]*//g' | sed 's/ -mcpu=[^ ]*//g' |sed 's/ -mtune=[^ ]*//g')" \
    CXX=${CXX_FOR_BUILD:-${CXX}} CC=${CC_FOR_BUILD:-${CC}} ./bootstrap.sh \
    --prefix="${PREFIX}" \
    --with-toolset=${TOOLSET} \
    --with-icu="${PREFIX}" \
    --with-python="${PYTHON}" \
    --with-python-root="${PREFIX} : ${PREFIX}/include/python${PY_VER}" \
    || (cat bootstrap.log && exit 1)

ADDRESS_MODEL="${ARCH}"
ARCHITECTURE=x86
ABI="sysv"

if [ "${ADDRESS_MODEL}" == "aarch64" ] || [ "${ADDRESS_MODEL}" == "arm64" ]; then
    ADDRESS_MODEL=64
    ARCHITECTURE=arm
    ABI="aapcs"
elif [ "${ADDRESS_MODEL}" == "ppc64le" ]; then
    ADDRESS_MODEL=64
    ARCHITECTURE=power
fi

if [[ "$target_platform" == osx-* ]]; then
    BINARY_FORMAT="mach-o"
elif [[ "$target_platform" == linux-* ]]; then
    BINARY_FORMAT="elf"
fi

mkdir temp_prefix

./b2 -q \
    --prefix=./temp_prefix \
    variant=release \
    address-model="${ADDRESS_MODEL}" \
    architecture="${ARCHITECTURE}" \
    binary-format="${BINARY_FORMAT}" \
    abi="${ABI}" \
    debug-symbols=off \
    threading=multi \
    runtime-link=shared \
    link=shared \
    toolset=${TOOLSET} \
    python="${PY_DUMMY_VER}" \
    include="${INCLUDE_PATH}" \
    cxxflags="${CXXFLAGS}" \
    linkflags="${LINKFLAGS}" \
    --layout=system \
    -j"${CPU_COUNT}" \
    install

# we package the (python-version-independent) headers here, whereas the libs
# are done in build-py.sh (because we need to build per python version)
rm -f ./temp_prefix/lib/libboost_python*
rm -f ./temp_prefix/lib/libboost_numpy*
rm -rf ./temp_prefix/lib/cmake/boost_python*
rm -rf ./temp_prefix/lib/cmake/boost_numpy*
