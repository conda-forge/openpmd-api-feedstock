REM Install library with openPMDConfig.cmake files with cmake

echo "CFLAGS: %CFLAGS%"
echo "CXXFLAGS: %CXXFLAGS%"
echo "LDFLAGS: %LDFLAGS%"

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


:: install API documentation: tagfile for xeus-cling
::   https://xeus-cling.readthedocs.io/en/latest/inline_help.html
set PKG_CONFIG_PATH=%PKG_CONFIG_PATH%;%LIBRARY_PREFIX%\lib\pkgconfig
for /f %%i in ('pkg-config --modversion openPMD') do set VERSION_FN=%%i
if errorlevel 1 exit 1
set VERSION_FN=%VERSION_FN%-alpha

mkdir -p %LIBRARY_PREFIX%\share\xeus-cling\tagfiles
mkdir -p %LIBRARY_PREFIX%\etc\xeus-cling\tags.d
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
