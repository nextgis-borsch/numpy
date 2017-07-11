################################################################################
# Project:  NumPy
# Purpose:  CMake build scripts
# Author:   Dmitry Baryshnikov, dmitry.baryshnikov@nexgis.com
################################################################################
# Copyright (C) 2016, NextGIS <info@nextgis.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
################################################################################

cmake_minimum_required(VERSION 2.8.12 FATAL_ERROR)

project(numpy)

# some init settings
set(CMAKE_COLOR_MAKEFILE ON)
# set path to additional CMake modules
set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

if(OSX_FRAMEWORK)
  set(INSTALL_LIB_DIR "${CMAKE_INSTALL_PREFIX}/Library" CACHE INTERNAL "Installation directory for libraries" FORCE)
else()
    include(GNUInstallDirs)
    set(INSTALL_LIB_DIR ${CMAKE_INSTALL_LIBDIR} CACHE INTERNAL "Installation directory for libraries" FORCE)
endif()

include(util)
check_version(NP_MAJOR_VERSION NP_MINOR_VERSION NP_MICRO_VERSION)
set(VERSION ${NP_MAJOR_VERSION}.${NP_MINOR_VERSION}.${NP_MICRO_VERSION})

report_version(${PROJECT_NAME} ${VERSION})

configure_file(${CMAKE_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake IMMEDIATE @ONLY)

if(NOT WITH_PYTHON2 AND NOT WITH_PYTHON3)
    set(WITH_PYTHON2 ON)
endif()

if(WITH_PYTHON2)
    if(WIN32)
        include(FindAnyProject)
        find_anyproject(python2 REQUIRED)
        
        if (NOT PYTHON2_FOUND)
            find_package(PythonInterp 2)
            if(PYTHONINTERP_FOUND)
                set(PYTHON2_EXECUTABLE ${PYTHON_EXECUTABLE})
            else()
                message(WARNING "Cannot find python 2")
            endif()
        endif()
    else()
        find_package(PythonInterp 2)
        if(PYTHONINTERP_FOUND)
            set(PYTHON2_EXECUTABLE ${PYTHON_EXECUTABLE})
            set(PYTHON2_VERSION_MAJOR ${PYTHON_VERSION_MAJOR})
            set(PYTHON2_VERSION_MINOR ${PYTHON_VERSION_MINOR})
        else()
            message(WARNING "Cannot find python 2")
        endif()
    endif()
endif()

unset(PYTHONINTERP_FOUND)
unset(PYTHON_EXECUTABLE)
unset(PYTHON_VERSION_MAJOR)
unset(PYTHON_VERSION_MINOR)

if(WITH_PYTHON3)
    # Hack, not find python3 withouut this
    find_program(PYTHON3_EXECUTABLE python3)
    set(PYTHON_EXECUTABLE ${PYTHON3_EXECUTABLE})

    find_package(PythonInterp 3)
    if(PYTHONINTERP_FOUND)
        set(PYTHON3_EXECUTABLE ${PYTHON_EXECUTABLE})
        set(PYTHON3_VERSION_MAJOR ${PYTHON_VERSION_MAJOR})
        set(PYTHON3_VERSION_MINOR ${PYTHON_VERSION_MINOR})
    else()
        message(WARNING "Cannot find python 3")
    endif()
endif()

if(NOT PYTHON2_EXECUTABLE AND NOT PYTHON3_EXECUTABLE)
    message(FATAL_ERROR "Cannot find python")
endif()

include(ProcessorCount)
ProcessorCount(N)
if(NOT N EQUAL 0)
    set(BUILD_FLAGS "-j ${N}")
else()
    set(BUILD_FLAGS)
endif()

if(WIN32)
    string(REPLACE "\\"
       "\\\\" VS120COMNTOOLS
       $ENV{VS120COMNTOOLS})
    set(FLAGS ${FLAGS} "VS90COMNTOOLS=${VS120COMNTOOLS}")
endif()

set(TARGET_NAME)
macro(build_py ver)
    set(TARGET_NAME build_py${ver})
    if(WIN32)
        add_custom_target(build_py${ver} ALL
            COMMAND ${CMAKE_COMMAND} -E env "${FLAGS}"
            ${PYTHON${ver}_EXECUTABLE} setup.py build
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )
    else()
        add_custom_target(build_py${ver} ALL
            ${PYTHON${ver}_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/setup.py build ${BUILD_FLAGS} -b ${CMAKE_CURRENT_BINARY_DIR}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
    endif()
endmacro()

if(PYTHON2_EXECUTABLE)
    build_py(2)
endif()

if(PYTHON3_EXECUTABLE)
    build_py(3)
endif()

if(NOT SKIP_INSTALL_LIBRARIES AND NOT SKIP_INSTALL_ALL )
if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    macro(install_mac_py ver)
        execute_process ( COMMAND ${PYTHON${ver}_EXECUTABLE} -c "import distutils.util; print(distutils.util.get_platform())" OUTPUT_VARIABLE PY_PLATFORM_NAME OUTPUT_STRIP_TRAILING_WHITESPACE)

        set(BINDING_PATH ${CMAKE_CURRENT_BINARY_DIR}/src.${PY_PLATFORM_NAME}-${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR})
        install(DIRECTORY "${BINDING_PATH}/"
                DESTINATION ${INSTALL_LIB_DIR}/Python/${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR}/site-packages
                COMPONENT libraries)

        set(BINDING_PATH ${CMAKE_CURRENT_BINARY_DIR}/lib.${PY_PLATFORM_NAME}-${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR})
        install(DIRECTORY "${BINDING_PATH}/"
                DESTINATION ${INSTALL_LIB_DIR}/Python/${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR}/site-packages
                COMPONENT libraries)
        install(DIRECTORY "${CMAKE_SOURCE_DIR}/numpy/core/include/numpy"
                DESTINATION ${INSTALL_LIB_DIR}/Python/${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR}/site-packages/numpy/core/include/
                PATTERN *.h)
    endmacro()

    if(PYTHON2_EXECUTABLE)
        install_mac_py(2)
    endif()

    if(PYTHON3_EXECUTABLE)
        install_mac_py(3)
    endif()
elseif(UNIX)
    macro(install_py ver)
        execute_process ( COMMAND ${PYTHON${ver}_EXECUTABLE} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())" OUTPUT_VARIABLE PY_SITE_PACKAGES OUTPUT_STRIP_TRAILING_WHITESPACE)

        set(TEST_CMD "try:
    import setuptools
    print(1)
except ImportError:
    pass")

        execute_process ( COMMAND ${PYTHON${ver}_EXECUTABLE} -c ${TEST_CMD} OUTPUT_VARIABLE PY_HAVE_SETUPTOOLS OUTPUT_STRIP_TRAILING_WHITESPACE)

        set(SETUP_OPTS)

        if(PY_HAVE_SETUPTOOLS)
            set(SETUP_OPTS "${SETUP_OPTS} --single-version-externally-managed --record=rekord.txt")
        endif()

        string( LENGTH "$ENV{DESTDIR}" DESTDIRLEN )
        if ( ${DESTDIRLEN} GREATER 0 )
            set(SETUP_OPTS "${SETUP_OPTS} --root=$ENV{DESTDIR}")
        elseif(PYTHON_DESTDIR)
            set(SETUP_OPTS "${SETUP_OPTS} --root=${PYTHON_DESTDIR}")
        endif()

        # check debian
        string(FIND ${PY_SITE_PACKAGES} "dist-packages" PY_DIST_POS)
        if(${PY_DIST_POS} GREATER -1)
            set(SETUP_OPTS "${SETUP_OPTS} --install-layout=deb")
        endif()

        # TODO: do we need --install-lib=$(PYTHON_INSTALL_LIB) ?

        set(SETUP_OPTS "${SETUP_OPTS} --prefix=${CMAKE_INSTALL_PREFIX}")

        if(NOT SUPPRESS_VERBOSE_OUTPUT)
            message(STATUS "setup tools options: ${SETUP_OPTS}")
        endif()

        install(CODE "execute_process(
                COMMAND ${PYTHON${ver}_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/setup.py install ${SETUP_OPTS}
                WORKING_DIRECTORY  ${CMAKE_CURRENT_BINARY_DIR}
                )")
        install(DIRECTORY "${CMAKE_SOURCE_DIR}/numpy/core/include/numpy"
                DESTINATION ${INSTALL_LIB_DIR}/Python/${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR}/site-packages/numpy/core/include/
                PATTERN *.h)
    endmacro()

    if(PYTHON2_EXECUTABLE)
        install_py(2)
    endif()

    if(PYTHON3_EXECUTABLE)
        install_py(3)
    endif()
else()
    macro(install_win_py ver)
        execute_process ( COMMAND ${PYTHON${ver}_EXECUTABLE} -c "import distutils.util; print(distutils.util.get_platform())" OUTPUT_VARIABLE PY_PLATFORM_NAME OUTPUT_STRIP_TRAILING_WHITESPACE)
        set(BINDING_PATH ${CMAKE_SOURCE_DIR}/build/lib.${PY_PLATFORM_NAME}-${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR})
        install(DIRECTORY "${BINDING_PATH}/"
                DESTINATION ${INSTALL_LIB_DIR}/Python${PYTHON${ver}_VERSION_MAJOR}${PYTHON${ver}_VERSION_MINOR}/site-packages
                COMPONENT libraries)
        set(BINDING_SRC_PATH ${CMAKE_SOURCE_DIR}/build/src.${PY_PLATFORM_NAME}-${PYTHON${ver}_VERSION_MAJOR}.${PYTHON${ver}_VERSION_MINOR})
        install(DIRECTORY "${BINDING_SRC_PATH}/numpy/core/include/numpy"
                DESTINATION ${INSTALL_LIB_DIR}/Python${PYTHON${ver}_VERSION_MAJOR}${PYTHON${ver}_VERSION_MINOR}/site-packages/numpy/core/include/
                PATTERN *.h)
        install(DIRECTORY "${CMAKE_SOURCE_DIR}/numpy/core/include/numpy"
                DESTINATION ${INSTALL_LIB_DIR}/Python${PYTHON${ver}_VERSION_MAJOR}${PYTHON${ver}_VERSION_MINOR}/site-packages/numpy/core/include/
                PATTERN *.h)
        
        if (REGISTER_PACKAGE)
            #export(TARGETS ${TARGET_NAME} FILE numpy-exports.cmake)

            set(EXPORT_PACKAGE_NAME numpy)
            set(EXPORT_PACKAGE_NAME_UPPER NUMPY)
            set(PACKAGE_PATH "${CMAKE_INSTALL_PREFIX}/${INSTALL_LIB_DIR}/Python${PYTHON${ver}_VERSION_MAJOR}${PYTHON${ver}_VERSION_MINOR}/site-packages")
            export(PACKAGE ${EXPORT_PACKAGE_NAME})

            include(CMakePackageConfigHelpers)
            configure_package_config_file(
                ${CMAKE_SOURCE_DIR}/cmake/PackageConfig.cmake.in
                ${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_PACKAGE_NAME}Config.cmake
            INSTALL_DESTINATION ${CMAKE_CURRENT_BINARY_DIR} )
            write_basic_package_version_file(
                ${CMAKE_CURRENT_BINARY_DIR}/${EXPORT_PACKAGE_NAME}ConfigVersion.cmake
                VERSION ${VERSION}
                COMPATIBILITY AnyNewerVersion )
        endif()
    endmacro()

    if(PYTHON2_EXECUTABLE)
        install_win_py(2)
    endif()

    if(PYTHON3_EXECUTABLE)
        install_win_py(3)
    endif()
endif()
endif()

add_custom_target(uninstall COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)