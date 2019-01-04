#!/bin/bash

mkdir build || true
cd build

declare -a CMAKE_PLATFORM_FLAGS
if [[ ${target_platform} =~ osx.* ]]; then
    # only needed until conda-forge toolchain 2.3.0 is used
    #   https://github.com/conda-forge/toolchain-feedstock/pull/47
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_OSX_SYSROOT="${CONDA_BUILD_SYSROOT}")
elif [[ ${target_platform} =~ linux.* ]]; then
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
    # link transitive ADIOS1 libraries during build of intermediate wrapper lib
    export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"
fi

bash ${SRC_DIR}/.travis/download_samples.sh

cmake \
    -DCMAKE_BUILD_TYPE=Release                       \
    -DCMAKE_SYSTEM_IGNORE_PATH=/usr/lib              \
    -DCMAKE_INSTALL_LIBDIR=lib                       \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}                 \
    "${CMAKE_PLATFORM_FLAGS[@]}"                     \
    -DPYTHON_EXECUTABLE:FILEPATH=$(which ${PYTHON})  \
    -DBUILD_TESTING=ON                               \
    -DopenPMD_USE_MPI=OFF                            \
    -DopenPMD_USE_HDF5=ON                            \
    -DopenPMD_USE_ADIOS1=ON                          \
    -DopenPMD_USE_ADIOS2=OFF                         \
    -DopenPMD_USE_PYTHON=ON                          \
    -DopenPMD_USE_INTERNAL_PYBIND11=ON               \
    ${SRC_DIR}

make ${VERBOSE_CM} -j${CPU_COUNT}
make ${VERBOSE_CM} test
make install
