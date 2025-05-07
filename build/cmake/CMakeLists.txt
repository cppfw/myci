cmake_minimum_required(VERSION 3.10)

include(GNUInstallDirs)

set(name myci)

project(${name})

# install cmake files
install(
    DIRECTORY
        ../../src/cmake
    DESTINATION
        ${CMAKE_INSTALL_DATAROOTDIR}/${name}
)
