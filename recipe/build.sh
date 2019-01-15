#!/bin/bash

mkdir build
cd build


declare -a CMAKE_PLATFORM_FLAGS
if [[ ${target_platform} =~ osx.* ]]; then
    # new compilers are properly sysrooted
    if [[ ${CXX} == "x86_64-apple-darwin13.4.0-clang++" ]]; then
        CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-osx.cmake")
    fi
    # https://stackoverflow.com/questions/49316779/dynamic-cast-dynamic-cast-fails-with-dylib-on-osx-xcode
    # export LDFLAGS="${LDFLAGS} -Wl,-flat_namespace"
elif [[ ${target_platform} =~ linux.* ]]; then
    # link transitive ADIOS1 libraries during build of intermediate wrapper lib
    export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"

    # old toolchain_cxx, compilers need pthread, m and rt from /
    if [[ ! -d /opt/rh/devtoolset-2/root ]]; then
        CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
    fi
fi


# find out toolchain C++ standard
CXX_STANDARD=11
CXX_EXTENSIONS=OFF
if [[ ${CXXFLAGS} == *"-std=c++11"* ]]; then
    echo "11"
    CXX_STANDARD=11
elif [[ ${CXXFLAGS} == *"-std=c++14"* ]]; then
    echo "14"
    CXX_STANDARD=14
elif [[ ${CXXFLAGS} == *"-std=c++17"* ]]; then
    echo "17"
    CXX_STANDARD=17
elif [[ ${CXXFLAGS} == *"-std="* ]]; then
    echo "ERROR: unknown C++ standard in toolchain!"
    echo ${CXXFLAGS}
    exit 1
fi


cmake \
    -DCMAKE_BUILD_TYPE=Debug  \
    -DCMAKE_CXX_STANDARD=${CXX_STANDARD}      \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON          \
    -DCMAKE_CXX_EXTENSIONS=${CXX_EXTENSIONS}  \
    -DopenPMD_USE_MPI=OFF       \
    -DopenPMD_USE_HDF5=ON       \
    -DopenPMD_USE_ADIOS1=ON     \
    -DopenPMD_USE_ADIOS2=OFF    \
    -DopenPMD_USE_PYTHON=ON     \
    -DopenPMD_USE_INTERNAL_PYBIND11=OFF              \
    -DPYTHON_EXECUTABLE:FILEPATH=$(which ${PYTHON})  \
    -DBUILD_TESTING=ON                \
    -DCMAKE_INSTALL_LIBDIR=lib        \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}  \
    ${CMAKE_PLATFORM_FLAGS[@]}        \
    ${SRC_DIR}

make ${VERBOSE_CM} -j${CPU_COUNT}

if [[ ${target_platform} =~ osx.* ]]; then
    otool -L ./bin/3_write_serial
    otool -L ./bin/SerialIOTests
    otool -L $SRC_DIR/build/lib/libopenPMD.ADIOS1.Serial.dylib
    otool -L $PREFIX/lib/libz.dylib
    otool -L $PREFIX/lib/libbz2.dylib
    otool -L $PREFIX/lib/libblosc.dylib

    #export DYLD_PRINT_LIBRARIES=1
    #export DYLD_PRINT_LIBRARIES_POST_LAUNCH=1
    #export DYLD_PRINT_RPATHS=1

    #./bin/3_write_serial
    #./bin/SerialIOTests -a -b
fi

make ${VERBOSE_CM} test
make install
