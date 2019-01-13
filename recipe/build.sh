#!/bin/bash

mkdir build
cd build


declare -a CMAKE_PLATFORM_FLAGS
if [[ ${target_platform} =~ osx.* ]]; then
    # only needed until conda-forge toolchain 2.3.0 is used
    #   https://github.com/conda-forge/toolchain-feedstock/pull/47
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_OSX_SYSROOT="${CONDA_BUILD_SYSROOT}")
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_FIND_ROOT_PATH="${PREFIX};${CONDA_BUILD_SYSROOT}")
elif [[ ${target_platform} =~ linux.* ]]; then
    # link transitive ADIOS1 libraries during build of intermediate wrapper lib
    export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"

    # old toolchain_cxx compilers needs pthread, m and rt from /
    if [[ ! -d /opt/rh/devtoolset-2/root ]]; then
        # CMAKE_PLATFORM_FLAGS+=(-DCMAKE_SYSTEM_PREFIX_PATH="/")
        # CMAKE_PLATFORM_FLAGS+=(-DFIND_LIBRARY_USE_LIB64_PATHS=ON)
    # else
        CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
        CMAKE_PLATFORM_FLAGS+=(-DCMAKE_SYSTEM_PREFIX_PATH="${BUILD_PREFIX}/${HOST}/sysroot")
    fi

    echo "BUILD_PREFIX: ${BUILD_PREFIX}"
    echo "SYSROOT:"
    ls ${BUILD_PREFIX}/${HOST}/sysroot || ( exit 0; )
    echo "SYSROOT - USR:"
    ls ${BUILD_PREFIX}/${HOST}/sysroot/usr || ( exit 0; )
    echo "PREFIX: ${PREFIX}"
    ls ${PREFIX} || ( exit 0; )
    echo "CXX: "
    which ${CXX}
    echo "CXX SYSROOT:"
    ${CXX} -print-sysroot || ( exit 0; )
    echo "CXX SYSROOT - HEADERS:"
    ${CXX} -print-sysroot-headers-suffix || ( exit 0; )
    echo "DEVTOOLSET:"
    ls /opt/rh/devtoolset-2/root || ( exit 0; )
    echo "DEVTOOLSET - USR:"
    ls /opt/rh/devtoolset-2/root/usr || ( exit 0; )

    echo "Find libpthread in DEVTOOLSET"
    find /opt/rh/devtoolset-2/ -name "libpthread*" || ( exit 0; )

    echo "Find libpthread in PREFIX"
    find ${PREFIX} -name "libpthread*" || ( exit 0; )

    echo "Find libpthread in BUILD_PREFIX"
    find ${BUILD_PREFIX} -name "libpthread*" || ( exit 0; )

    echo "Find libpthread in /"
    find / -name "libpthread*" 2>/dev/null || ( exit 0; )
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


# -DCMAKE_SYSTEM_IGNORE_PATH=/usr/lib
cmake \
    -DCMAKE_BUILD_TYPE=Release  \
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
make ${VERBOSE_CM} test
make install
