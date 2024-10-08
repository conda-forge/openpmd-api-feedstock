REM Install library with openPMDConfig.cmake files with cmake

echo "CFLAGS: %CFLAGS%"
echo "CXXFLAGS: %CXXFLAGS%"
echo "LDFLAGS: %LDFLAGS%"

mkdir build
cd build

set CURRENTDIR="%cd%"

:: FIXME: ADIOS2 has no PyPy support yet (internally shipped, unpatched pybind11<2.6.0)
::   https://github.com/conda-forge/adios2-feedstock/pull/16
::   https://github.com/ornladios/ADIOS2/issues/2068
if "%python_impl%" == "pypy" (set USE_ADIOS2="OFF") else (set USE_ADIOS2="ON")

cmake ^
    %CMAKE_ARGS%                ^
    -G "NMake Makefiles"        ^
    -DCMAKE_BUILD_TYPE=Release  ^
    -DBUILD_SHARED_LIBS=ON      ^
    -DopenPMD_USE_MPI=OFF       ^
    -DopenPMD_USE_HDF5=ON       ^
    -DopenPMD_USE_ADIOS2=%USE_ADIOS2%    ^
    -DopenPMD_USE_PYTHON=ON     ^
    -DopenPMD_USE_INTERNAL_CATCH=ON      ^
    -DopenPMD_USE_INTERNAL_PYBIND11=OFF  ^
    -DopenPMD_USE_INTERNAL_TOML11=ON     ^
    -DPython_EXECUTABLE:FILEPATH=%PYTHON%    ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX%  ^
    -DCMAKE_INSTALL_LIBDIR=lib  ^
    -DopenPMD_INSTALL_PYTHONDIR=%SP_DIR%  ^
    -DopenPMD_PYTHON_OUTPUT_DIRECTORY=%CURRENTDIR%\lib\site-packages  ^
    %SRC_DIR%
if errorlevel 1 exit 1

nmake
if errorlevel 1 exit 1

:: temporarily disabled due to missing lib hints for Python
:: nmake test
:: if errorlevel 1 exit 1

nmake install
if errorlevel 1 exit 1


:: install API documentation: tagfile for xeus-cling
::   https://xeus-cling.readthedocs.io/en/latest/inline_help.html
set PKG_CONFIG_PATH=%PKG_CONFIG_PATH%;%LIBRARY_PREFIX%\lib\pkgconfig
for /f %%i in ('pkg-config --modversion openPMD') do set VERSION_FN=%%i
if errorlevel 1 exit 1
set VERSION_FN=%VERSION_FN%

mkdir %LIBRARY_PREFIX%\share\xeus-cling\tagfiles
mkdir %LIBRARY_PREFIX%\etc\xeus-cling\tags.d
curl -sOL https://openpmd-api.readthedocs.io/en/%VERSION_FN%/_static/doxyhtml/openpmd-api-doxygen-web.tag.xml
copy openpmd-api-doxygen-web.tag.xml %LIBRARY_PREFIX%\share\xeus-cling\tagfiles\ || exit 1
if errorlevel 1 exit 1

(
echo {
echo     "url": "https://openpmd-api.readthedocs.io/en/%VERSION_FN%/_static/doxyhtml/",
echo     "tagfile": "openpmd-api-doxygen-web.tag.xml"
echo }
)>"%LIBRARY_PREFIX%\etc\xeus-cling\tags.d\openpmd-api.json"
type %LIBRARY_PREFIX%\etc\xeus-cling\tags.d\openpmd-api.json || exit 1
if errorlevel 1 exit 1
