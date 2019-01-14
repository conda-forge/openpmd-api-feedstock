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
