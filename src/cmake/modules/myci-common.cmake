if(MYCI_COMMON_CMAKE_INCLUDED)
    return()
endif()
set(MYCI_COMMON_CMAKE_INCLUDED TRUE)

include(GNUInstallDirs)

get_property(generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG SET)

# TODO: remove the _ prefix?
set(exe_output_dir "${CMAKE_BINARY_DIR}/_exe")

# TODO: why disabling this warning?
if(MSVC)
    add_definitions(
        /wd5055 # operator '*': deprecated between enumerations and floating-point types
    )
endif()

macro(add_source_directory out srcdir)
    set(options RECURSIVE)
    set(single)
    set(multiple PATTERNS)
    cmake_parse_arguments(asd "${options}" "${single}" "${multiple}" ${ARGN})

    set(glob GLOB)
    if(asd_RECURSIVE)
        set(glob GLOB_RECURSE)
    endif()

    set(patterns)
    foreach(pattern ${asd_PATTERNS})
        list(APPEND patterns "${srcdir}/${pattern}")
    endforeach()

    file(${glob} globresult RELATIVE "${srcdir}" CONFIGURE_DEPENDS ${patterns})
    foreach(file ${globresult})
        get_filename_component(path "${file}" DIRECTORY)
        string(REPLACE "/" "\\" path "Source Files/${path}")
        source_group("${path}" FILES "${srcdir}/${file}")
        list(APPEND ${out} "${srcdir}/${file}")
    endforeach()
endmacro()

macro(install_resource_file out srcfile dstfile)
    set(outfile "${exe_output_dir}/${dstfile}")

    get_filename_component(path "${dstfile}" DIRECTORY)
    string(REPLACE "/" "\\" path "Generated Files/${path}")
    source_group("${path}" FILES "${outfile}")
    list(APPEND ${out} "${outfile}")

    add_custom_command(
        OUTPUT
            "${outfile}"
        COMMAND
            "${CMAKE_COMMAND}" -E copy "${srcfile}" "${outfile}"
        DEPENDS
            "${srcfile}"
        MAIN_DEPENDENCY
            "${srcfile}"
    )
endmacro()

macro(add_resource_directory out srcdir)
    get_filename_component(dirname "${srcdir}" NAME)

    file(GLOB_RECURSE globresult RELATIVE "${srcdir}" CONFIGURE_DEPENDS "${srcdir}/*")

    foreach(file ${globresult})
        get_filename_component(path "${file}" DIRECTORY)
        string(REPLACE "/" "\\" path "Resource Files/${path}")
        source_group("${path}" FILES "${srcdir}/${file}")
        list(APPEND ${out} "${srcdir}/${file}")

        if(NOT ${generator_is_multi_config})
            install_resource_file(${out} "${srcdir}/${file}" "${dirname}/${file}")
        else()
            foreach(cfg ${CMAKE_CONFIGURATION_TYPES})
                install_resource_file(${out} "${srcdir}/${file}" "${cfg}/${dirname}/${file}")
            endforeach()
        endif()

        if(${install})
            install(
                FILE
                    "${srcdir}/${file}"
                DESTINATION
                    "${CMAKE_INSTALL_DATADIR}/${dirname}"
            )
        endif()
    endforeach()
endmacro()

macro(add_target_dependencies target visibility)
    foreach(dep ${ARGN})
        if(NOT TARGET ${dep}::${dep})
            find_package(${dep} CONFIG REQUIRED)
        endif()
        target_link_libraries(${target} ${visibility} ${dep}::${dep})
    endforeach()
endmacro()

macro(add_target_external_dependencies target visibility)
    foreach(dep ${dl_EXTERNAL_DEPENDENCIES})
        if(NOT TARGET ${dep}::${dep})
            find_package(${dep} REQUIRED)
        endif()
        target_link_libraries(${target} ${visibility} ${dep}::${dep})
    endforeach()
endmacro()

macro(declare_library name)
    set(options)
    set(single INSTALL)
    set(multiple SOURCES RESOURCES DEPENDENCIES EXTERNAL_DEPENDENCIES
        PRIVATE_INCLUDE_DIRECTORIES PUBLIC_INCLUDE_DIRECTORIES INSTALL_INCLUDE_DIRECTORIES)
    cmake_parse_arguments(dl "${options}" "${single}" "${multiple}" ${ARGN})

    # Check if {NAME}_DISABLE_INSTALL variable is set and act accordingly
    string(TOUPPER "${name}" nameupper)
    string(REPLACE "-" "_" nameupper "${nameupper}")
    set(install TRUE)
    if(${nameupper}_DISABLE_INSTALL)
        set(install FALSE)
    endif()

    # Normally we create STATIC libraries and specify PUBLIC includes and dependencies.
    # For libraries with no source files this won't work, so use INTERFACE/INTERFACE instead.
    set(public INTERFACE)
    set(static INTERFACE)
    foreach(src ${dl_SOURCES})
        get_filename_component(ext "${src}" LAST_EXT)
        if("${ext}" STREQUAL ".c" OR "${ext}" STREQUAL ".cpp" OR "${ext}" STREQUAL ".cc")
            set(public PUBLIC)
            set(static STATIC)
            break()
        endif()
    endforeach()

    add_library(${name} ${static} ${dl_SOURCES} ${dl_RESOURCES})

    target_compile_features(${name} ${public} cxx_std_20)
    set_target_properties(${name} PROPERTIES CXX_STANDARD_REQUIRED ON)
    set_target_properties(${name} PROPERTIES CXX_EXTENSIONS OFF)

    foreach(dir ${dl_PUBLIC_INCLUDE_DIRECTORIES})
        target_include_directories(${name} ${public} $<BUILD_INTERFACE:${dir}>)
    endforeach()

    foreach(dir ${dl_PRIVATE_INCLUDE_DIRECTORIES})
        target_include_directories(${name} PRIVATE $<BUILD_INTERFACE:${dir}>)
    endforeach()

    add_target_dependencies(${name} ${public} ${dl_DEPENDENCIES})
    add_target_external_dependencies(${name} ${public} ${dl_EXTERNAL_DEPENDENCIES})

    if(${install})
        target_include_directories(${name} ${public} $<INSTALL_INTERFACE:include>)
        # install library header files preserving directory hierarchy
        foreach(dir ${dl_INSTALL_INCLUDE_DIRECTORIES})
            install(
                DIRECTORY
                    "${dir}"
                DESTINATION
                    "${CMAKE_INSTALL_INCLUDEDIR}"
                FILES_MATCHING
                    PATTERN "*.h"
                    PATTERN "*.hpp"
                    PATTERN "*.hh" # TODO: why support this extension?
            )
        endforeach()
        # generate cmake configs
        install(
            TARGETS
                ${name}
            EXPORT
                ${name}-config
        )
        # install cmake configs
        install(
            EXPORT
                ${name}-config
            FILE
                ${name}-config.cmake
            DESTINATION
                "${CMAKE_INSTALL_DATAROOTDIR}/${name}"
            NAMESPACE
                "${name}::"
        )
    endif()
endmacro()

macro(declare_executable name)
    set(options)
    set(single)
    set(multiple SOURCES INCLUDE_DIRECTORIES LINK_LIBRARIES DEPENDENCIES EXTERNAL_DEPENDENCIES)
    cmake_parse_arguments(dl "${options}" "${single}" "${multiple}" ${ARGN})

    add_executable(${name} ${dl_SOURCES})
    target_compile_features(${name} PRIVATE cxx_std_20)

    set_target_properties(${name} PROPERTIES
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        VS_DEBUGGER_WORKING_DIRECTORY "${exe_output_dir}/$<CONFIG>"
        RUNTIME_OUTPUT_DIRECTORY "${exe_output_dir}"
    )

    foreach(dir ${dl_INCLUDE_DIRECTORIES})
        target_include_directories(${name} PRIVATE "${dir}")
    endforeach()

    foreach(lib ${dl_LINK_LIBRARIES})
        target_link_libraries(${name} PRIVATE "${lib}")
    endforeach()

    add_target_dependencies(${name} PRIVATE ${dl_DEPENDENCIES})
    add_target_external_dependencies(${name} PRIVATE ${dl_EXTERNAL_DEPENDENCIES})
endmacro()
