cmake_minimum_required(VERSION 3.10)

set(CMAKE_TOOLCHAIN_FILE $ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)

project(test)

# get_cmake_property(_variableNames VARIABLES)
# list (SORT _variableNames)
# foreach (_variableName ${_variableNames})
#     message(STATUS "${_variableName}=${${_variableName}}")
# endforeach()

if(NOT DEFINED myci_DIR)
    message(FATAL_ERROR "myci_DIR is not defined by vcpkg")
endif()

find_package(myci CONFIG REQUIRED)

message("exe_output_dir = ${exe_output_dir}")

message("!!!  PASSED: myci vcpkg package test  !!!")
