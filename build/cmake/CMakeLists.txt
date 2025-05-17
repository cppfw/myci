cmake_minimum_required(VERSION 3.10)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(name myci)

project(${name})

# TODO: parse version from debian/changelog
# write_basic_package_version_file(
#   ../../src/cmake/${PROJECT_NAME}-config-version.cmake
#   VERSION 1.2.3
#   COMPATIBILITY SameMinorVersion
# )

# install cmake modules
install(
    DIRECTORY
        ../../src/cmake
    DESTINATION
        ${CMAKE_INSTALL_DATAROOTDIR}/${name}
)

install(
    TARGETS
        ${name}
    EXPORT # generate cmake configs
        ${name}-config
)

# install cmake config
install(
    EXPORT
        ${name}-config
    FILE
        ${name}-config.cmake
    DESTINATION
        ${CMAKE_INSTALL_DATAROOTDIR}/${name}/cmake
    NAMESPACE
        ${name}::
)
