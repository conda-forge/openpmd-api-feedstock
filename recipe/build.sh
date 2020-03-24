#!/bin/bash

mkdir build
cd build


declare -a CMAKE_PLATFORM_FLAGS
if [[ ${target_platform} =~ osx.* ]]; then
    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-osx.cmake")
elif [[ ${target_platform} =~ linux.* ]]; then
    # link transitive ADIOS1 libraries during build of intermediate wrapper lib
    export LDFLAGS="${LDFLAGS} -Wl,-rpath-link,${PREFIX}/lib"

    CMAKE_PLATFORM_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE="${RECIPE_DIR}/cross-linux.cmake")
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


# FIXME: ADIOS1 broken with MPICH
if [[ ${mpi} == "mpich" && ${target_platform} =~ osx.* ]]; then
    export USE_ADIOS1=OFF
else
    export USE_ADIOS1=ON
fi


# MPI variants
if [[ ${mpi} == "nompi" ]]; then
    export USE_MPI=OFF
else
    export USE_MPI=ON
fi
#   see https://github.com/conda-forge/hdf5-feedstock/blob/master/recipe/mpiexec.sh
if [[ "$mpi" == "mpich" ]]; then
    export HYDRA_LAUNCHER=fork
    #export HYDRA_LAUNCHER=ssh
fi
if [[ "$mpi" == "openmpi" ]]; then
    export OMPI_MCA_btl=self,tcp
    export OMPI_MCA_plm=isolated
    #export OMPI_MCA_plm=ssh
    export OMPI_MCA_rmaps_base_oversubscribe=yes
    export OMPI_MCA_btl_vader_single_copy_mechanism=none
fi

cmake \
    -DCMAKE_BUILD_TYPE=Release  \
    -DBUILD_SHARED_LIBS=ON      \
    -DCMAKE_CXX_STANDARD=${CXX_STANDARD}      \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON          \
    -DCMAKE_CXX_EXTENSIONS=${CXX_EXTENSIONS}  \
    -DopenPMD_USE_MPI=${USE_MPI}              \
    -DopenPMD_USE_HDF5=ON       \
    -DopenPMD_USE_ADIOS1=${USE_ADIOS1}        \
    -DopenPMD_USE_ADIOS2=ON     \
    -DopenPMD_USE_PYTHON=ON     \
    -DopenPMD_USE_INTERNAL_PYBIND11=OFF              \
    -DPYTHON_EXECUTABLE:FILEPATH=$(which ${PYTHON})  \
    -DBUILD_TESTING=ON                \
    -DCMAKE_INSTALL_LIBDIR=lib        \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}  \
    ${CMAKE_PLATFORM_FLAGS[@]}        \
    ${SRC_DIR}

# compiler error or resource exhaustion on PPC64le Travis-CI builds with:
#   powerpc64le-conda_cos7-linux-gnu-c++: fatal error: Killed signal terminated program cc1plus
#   FIXME: https://github.com/conda-forge/conda-forge-ci-setup-feedstock/pull/68
if [[ ${target_platform} =~ .*ppc64le.* ]]; then
  export CPU_COUNT=2
fi
make ${VERBOSE_CM} -j${CPU_COUNT}

if [[ ${target_platform} =~ .*aarch64.* ]] && [[ "$mpi" == "openmpi" ]]; then
    # QEMU on MPI startup: "getsockopt level=1 optname=20 not yet supported"
    # https://github.com/qemu/qemu/blob/586f3dced9f2b354480c140c070a3d02a0c66a1e/linux-user/syscall.c#L2530-L2535
    echo "Skipping OpenMPI runtime tests on QEMU for aarch64 due to lack of support..."
else
    CTEST_OUTPUT_ON_FAILURE=1 make ${VERBOSE_CM} test
fi

make install


# install API documentation: tagfile for xeus-cling
#   https://xeus-cling.readthedocs.io/en/latest/inline_help.html
version_fn="$(pkg-config --modversion openPMD)-alpha"

mkdir -p ${PREFIX}/share/xeus-cling/tagfiles
mkdir -p ${PREFIX}/etc/xeus-cling/tags.d
curl -sOL https://openpmd-api.readthedocs.io/en/${version_fn}/_static/doxyhtml/openpmd-api-doxygen-web.tag.xml
mv openpmd-api-doxygen-web.tag.xml ${PREFIX}/share/xeus-cling/tagfiles/

cat > ${PREFIX}/etc/xeus-cling/tags.d/openpmd-api.json << TextDelimiter
{
    "url": "https://openpmd-api.readthedocs.io/en/${version_fn}/_static/doxyhtml/",
    "tagfile": "openpmd-api-doxygen-web.tag.xml"
}
TextDelimiter
cat ${PREFIX}/etc/xeus-cling/tags.d/openpmd-api.json
