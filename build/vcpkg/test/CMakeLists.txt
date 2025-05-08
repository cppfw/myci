cmake_minimum_required(VERSION 3.10)

set(CMAKE_TOOLCHAIN_FILE $ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)

project(test)

find_package(myci CONFIG REQUIRED)

include(myci)

message("exe_output_dir = ${exe_output_dir}")

message("!!!  PASSED: myci vcpkg package test  !!!")
