REM Install library with openPMDConfig.cmake files with cmake

:: remove -GL (whole program optimization) from CXXFLAGS
:: causes a fatal error when linking our .dll
echo "%CXXFLAGS%"
set CXXFLAGS=%CXXFLAGS: -GL=%
echo "%CXXFLAGS%"

mkdir build
cd build

set CURRENTDIR="%cd%"

cmake ^
    -G "NMake Makefiles"        ^
    -DCMAKE_BUILD_TYPE=Release  ^
    -DBUILD_SHARED_LIBS=ON      ^
    -DopenPMD_USE_MPI=OFF       ^
    -DopenPMD_USE_HDF5=ON       ^
    -DopenPMD_USE_ADIOS1=OFF    ^
    -DopenPMD_USE_ADIOS2=ON     ^
    -DopenPMD_USE_PYTHON=ON     ^
    -DopenPMD_USE_INTERNAL_PYBIND11=OFF  ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX%  ^
    -DCMAKE_INSTALL_LIBDIR=lib  ^
    -DCMAKE_INSTALL_PYTHONDIR=%SP_DIR%  ^
    -DCMAKE_PYTHON_OUTPUT_DIRECTORY=%CURRENTDIR%\lib\site-packages  ^
    %SRC_DIR%
if errorlevel 1 exit 1

nmake
if errorlevel 1 exit 1

nmake test
if errorlevel 1 exit 1

nmake install
if errorlevel 1 exit 1
