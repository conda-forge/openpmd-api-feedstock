#!/bin/bash

mkdir build
cd build

# for cross compiling using openmpi
export OPAL_PREFIX=${PREFIX}

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # Fix for cmake bug when cross-compiling
    export CFLAGS="$CFLAGS $LDFLAGS"
    export CXXFLAGS="$CXXFLAGS $LDFLAGS"
fi

# newer C++ standard lib features
# https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
if [[ ${target_platform} =~ osx.* ]]; then
    export CXXFLAGS="$CXXFLAGS -D_LIBCPP_DISABLE_AVAILABILITY"  # conda-forge ships its own (modern) libcxx
fi

# FIXME: ADIOS2 has no PyPy support yet (internally shipped, unpatched pybind11<2.6.0)
#   https://github.com/conda-forge/adios2-feedstock/pull/16
#   https://github.com/ornladios/ADIOS2/issues/2068
if [[ ${python_impl} == "pypy" ]]; then
    export USE_ADIOS2=OFF
    if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
        # work-around for PyPy 3.7:
        PYTHON_MODULE_EXTENSION=$(${PYTHON} -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))")
        # 1) setuptools seems to always add x86_64 instead of the cross-arch
        #    https://github.com/conda-forge/openpmd-api-feedstock/pull/86
        #    https://github.com/benfogle/crossenv/pull/86
        # e.g.: pypy37-pp73-x86_64-linux-gnu.so -> pypy37-pp73-aarch64-linux-gnu.so
        #PYTHON_MODULE_EXTENSION="${PYTHON_MODULE_EXTENSION/x86_64/$cdt_arch}"
        # 2) PyPy 3.7 for C module extensions forgot the arch in this release altogether.
        #    This is fixed in PyPy3.8.
        # e.g.: pypy37-pp73-x86_64-linux-gnu.so -> pypy37-pp73-linux-gnu.so
        PYTHON_MODULE_EXTENSION="${PYTHON_MODULE_EXTENSION/x86_64-/}"
        export CMAKE_ARGS="${CMAKE_ARGS} -DPYTHON_MODULE_EXTENSION=${PYTHON_MODULE_EXTENSION} -DPYBIND11_PYTHON_EXECUTABLE_LAST=$PYTHON"
    fi
else
    export USE_ADIOS2=ON
fi

# MPI variants
if [[ ${mpi} == "nompi" ]]; then
    export USE_MPI=OFF
else
    export USE_MPI=ON
fi

echo "Some CMAKE_ARGS=${CMAKE_ARGS}"

cmake ${CMAKE_ARGS} \
    -DCMAKE_BUILD_TYPE=Release  \
    -DBUILD_SHARED_LIBS=ON      \
    -DopenPMD_USE_MPI=${USE_MPI}              \
    -DopenPMD_USE_HDF5=ON                     \
    -DopenPMD_USE_ADIOS2=${USE_ADIOS2}        \
    -DopenPMD_USE_PYTHON=ON                   \
    -DopenPMD_SUPERBUILD=OFF                  \
    -DopenPMD_USE_INTERNAL_CATCH=ON           \
    -DopenPMD_USE_INTERNAL_TOML11=ON          \
    -DPython_EXECUTABLE:FILEPATH=$PYTHON      \
    -DBUILD_TESTING=ON                \
    -DCMAKE_INSTALL_LIBDIR=lib        \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}  \
    -DPython_INCLUDE_DIR=$(${PYTHON} -c "from sysconfig import get_paths as gp; print(gp()['include'])") \
    ${SRC_DIR}                     || \
{ cat $SRC_DIR/build/CMakeFiles/CMakeOutput.log; \
  cat $SRC_DIR/build/CMakeFiles/CMakeError.log; exit 1; }

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
elif [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    echo "Skipping runtime tests due to cross-compiled target..."
else
    CTEST_OUTPUT_ON_FAILURE=1 make ${VERBOSE_CM} test
fi

make install


# install API documentation: tagfile for xeus-cling
#   https://xeus-cling.readthedocs.io/en/latest/inline_help.html
version_fn="$(pkg-config --modversion openPMD)"

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
