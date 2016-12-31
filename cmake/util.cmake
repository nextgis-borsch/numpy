################################################################################
# Project:  CMake4GDAL
# Purpose:  CMake build scripts
# Author:   Dmitry Baryshnikov, polimax@mail.ru
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


function(check_version major minor micro)

    # parse the version number from gdal_version.h and include in
    # major, minor and rev parameters

    set(VER_FILE ${CMAKE_CURRENT_SOURCE_DIR}/setup.py)

    file(READ ${VER_FILE} NP_VERSION_CONTENTS)

    string(REGEX MATCH "MAJOR[ \t]=+([0-9]+)"
      NP_MAJOR_VERSION ${NP_VERSION_CONTENTS})
    string (REGEX MATCH "([0-9]+)"
      NP_MAJOR_VERSION ${NP_MAJOR_VERSION})
    string(REGEX MATCH "MINOR[ \t]=+([0-9]+)"
      NP_MINOR_VERSION ${NP_VERSION_CONTENTS})
    string (REGEX MATCH "([0-9]+)"
      NP_MINOR_VERSION ${NP_MINOR_VERSION})
    string(REGEX MATCH "MICRO[ \t]=+([0-9]+)"
      NP_MICRO_VERSION ${NP_VERSION_CONTENTS})
    string (REGEX MATCH "([0-9]+)"
      NP_MICRO_VERSION ${NP_MICRO_VERSION})

    set(${major} ${NP_MAJOR_VERSION} PARENT_SCOPE)
    set(${minor} ${NP_MINOR_VERSION} PARENT_SCOPE)
    set(${micro} ${NP_MICRO_VERSION} PARENT_SCOPE)

    # Store version string in file for installer needs
    file(TIMESTAMP ${VER_FILE} VERSION_DATETIME "%Y-%m-%d %H:%M:%S" UTC)
    file(WRITE ${CMAKE_BINARY_DIR}/version.str "${NP_MAJOR_VERSION}.${NP_MINOR_VERSION}.${NP_MICRO_VERSION}\n${VERSION_DATETIME}")

endfunction(check_version)

# search python module
function(find_python_module module)
    string(TOUPPER ${module} module_upper)
    if(ARGC GREATER 1 AND ARGV1 STREQUAL "REQUIRED")
        set(${module}_FIND_REQUIRED TRUE)
    else()
        if (ARGV1 STREQUAL "QUIET")
            set(PY_${module}_FIND_QUIETLY TRUE)
        endif()
    endif()

    if(NOT PY_${module_upper})
        # A module's location is usually a directory, but for binary modules
        # it's a .so file.
        execute_process(COMMAND "${PYTHON_EXECUTABLE}" "-c"
            "import re, ${module}; print(re.compile('/__init__.py.*').sub('',${module}.__file__))"
            RESULT_VARIABLE _${module}_status
            OUTPUT_VARIABLE _${module}_location
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(NOT _${module}_status)
            set(PY_${module_upper} ${_${module}_location} CACHE STRING
                "Location of Python module ${module}")
        endif(NOT _${module}_status)
    endif(NOT PY_${module_upper})
    find_package_handle_standard_args(PY_${module} DEFAULT_MSG PY_${module_upper})
endfunction(find_python_module)

function(report_version name ver)

    string(ASCII 27 Esc)
    set(BoldYellow  "${Esc}[1;33m")
    set(ColourReset "${Esc}[m")

    message(STATUS "${BoldYellow}${name} version ${ver}${ColourReset}")

endfunction()

function(warning_msg text)
    if(NOT SUPPRESS_VERBOSE_OUTPUT)
    string(ASCII 27 Esc)
    set(Red         "${Esc}[31m")
    set(ColourReset "${Esc}[m")

    message(STATUS "${Red}${text}${ColourReset}")
    endif()
endfunction()
