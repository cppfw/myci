if(MYCI_MODULE_INCLUDED)
    return()
endif()
set(MYCI_MODULE_INCLUDED TRUE)

include(GNUInstallDirs)

get_property(myci_generator_is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG SET)

set(myci_exe_output_dir "${CMAKE_BINARY_DIR}/out")

# TODO: warnings in agg are fixed. Remove this warning suppression when sure.
#if(MSVC)
#    add_definitions(
#        /wd5055 # operator '*': deprecated between enumerations and floating-point types
#    )
#endif()

####
# @brief Get install flag for current project.
# Checks if <UPPERCASE_PROJECT_NAME>_DISABLE_INSTALL variable is defined and if it is TRUE then sets ${var} to FALSE,
# otherwise sets ${var} to TRUE.
# In case the <UPPERCASE_PROJECT_NAME>_DISABLE_INSTALL is not defined, then checks value of MYCI_GLOBAL_DISABLE_INSTALL
# variable, if it is true then sets ${var} to FALSE, otherwise sets ${var} to TRUE.
# @param var - variable name to store the flag value to.
function(myci_get_install_flag var)
    # Check if {CMAKE_PROJECT_NAME}_DISABLE_INSTALL variable is set and act accordingly
    string(TOUPPER "${CMAKE_PROJECT_NAME}" nameupper)
    string(REPLACE "-" "_" nameupper "${nameupper}")

    set(${var} TRUE PARENT_SCOPE)

    if(DEFINED ${nameupper}_DISABLE_INSTALL)
        if(${nameupper}_DISABLE_INSTALL)
            set(${var} FALSE PARENT_SCOPE)
        endif()
    else()
        if(MYCI_GLOBAL_DISABLE_INSTALL)
            set(${var} FALSE PARENT_SCOPE)
        endif()
    endif()
endfunction()

####
# @brief Add source files from a directory to a list variable.
# @param out - list variable name to which to append source files.
# @param DIRECTORY <dir> - directory to look for source files in. Required.
# @param RECURSIVE - look for source files recursively. Optional.
# @param PATTERNS <pattern1> [<pattern2> ...] - list of file patterns to include. Example: '*.cpp *.c'.
#                 Defaults to '*.cpp *.c *.hpp *.h'.
function(myci_add_source_files out)
    set(options RECURSIVE)
    set(single DIRECTORY)
    set(multiple PATTERNS)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_DIRECTORY)
        message(FATAL_ERROR "myci_add_source_files(): required argument DIRECTORY is empty")
    endif()

    if(NOT arg_PATTERNS)
        # TODO: why append headers to sources?
        list(APPEND arg_PATTERNS "*.cpp" "*.c" "*.hpp" "*.h")
    endif()

    set(patterns)
    foreach(pattern ${arg_PATTERNS})
        list(APPEND patterns "${arg_DIRECTORY}/${pattern}")
    endforeach()

    file(REAL_PATH
        # PATH
            "${arg_DIRECTORY}"
        # OUTPUT
            abs_path_directory
        BASE_DIRECTORY
            ${CMAKE_CURRENT_LIST_DIR}
        EXPAND_TILDE
    )

    if(arg_RECURSIVE)
        set(glob GLOB_RECURSE)
    else()
        set(glob GLOB)
    endif()

    file(
        ${glob}
        globresult
        FOLLOW_SYMLINKS
        CONFIGURE_DEPENDS
        LIST_DIRECTORIES
            false
        # If arg_DIRECTORY is relative and has '..' in front then this does not work.
        # So, use absoulte directory path.
        RELATIVE
            "${abs_path_directory}"
        ${patterns}
    )

    if(NOT globresult)
        message(WARNING "myci_add_source_files(): no source files found")
    endif()

    set(result_files)
    foreach(file ${globresult})
        # stuff for Visual Studio
        get_filename_component(path "${file}" DIRECTORY)
        string(REPLACE "/" "\\" path "Source Files/${path}")
        source_group("${path}" FILES "${arg_DIRECTORY}/${file}")

        list(APPEND result_files "${arg_DIRECTORY}/${file}")
    endforeach()

    set(${out} ${result_files} PARENT_SCOPE)
endfunction()

function(myci_install_resource_file out srcfile dstfile)
    set(outfile "${myci_exe_output_dir}/${dstfile}")

    # stuff for Visual Studio
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
endfunction()

# TODO: refactor
function(myci_add_resource_files out)
    set(options RECURSIVE)
    set(single DIRECTORY)
    set(multiple PATTERNS)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_DIRECTORY)
        message(FATAL_ERROR "myci_add_resource_files(): required argument DIRECTORY is empty")
    endif()

    get_filename_component(dirname "${arg_DIRECTORY}" NAME)

    file(REAL_PATH
        # PATH
            "${arg_DIRECTORY}"
        # OUTPUT
            abs_path_directory
        BASE_DIRECTORY
            ${CMAKE_CURRENT_LIST_DIR}
        EXPAND_TILDE
    )

    file(
        GLOB_RECURSE
            globresult
        # If arg_DIRECTORY is relative and has '..' in front then this does not work.
        # So, use absoulte directory path.
        RELATIVE
            ${abs_path_directory}
        FOLLOW_SYMLINKS
        CONFIGURE_DEPENDS
        LIST_DIRECTORIES
            false
        "${arg_DIRECTORY}/*"
    )

    set(result_files)
    foreach(file ${globresult})
        # stuff for Visual Studio
        get_filename_component(path "${file}" DIRECTORY)
        string(REPLACE "/" "\\" path "Resource Files/${path}")
        source_group("${path}" FILES "${arg_DIRECTORY}/${file}")

        list(APPEND result_files "${arg_DIRECTORY}/${file}")

        if(${myci_generator_is_multi_config})
            foreach(cfg ${CMAKE_CONFIGURATION_TYPES})
                myci_install_resource_file(${out} "${arg_DIRECTORY}/${file}" "${cfg}/${dirname}/${file}")
            endforeach()
        else()
            myci_install_resource_file(${out} "${arg_DIRECTORY}/${file}" "${dirname}/${file}")
        endif()

        myci_get_install_flag(install)
        if(${install})
            install(
                FILES
                    "${arg_DIRECTORY}/${file}"
                DESTINATION
                    "${CMAKE_INSTALL_DATADIR}/${dirname}"
            )
        endif()
    endforeach()

    set(${out} ${result_files} PARENT_SCOPE)
endfunction()

function(myci_add_target_dependencies target visibility)
    foreach(dep ${ARGN})
        if(NOT TARGET ${dep}::${dep})
            find_package(${dep} CONFIG REQUIRED)
        endif()
        target_link_libraries(${target} ${visibility} ${dep}::${dep})
    endforeach()
endfunction()

# TODO: remove ANGLE-related stuff when the ANGLE lib is packaged properly.
# macro(myci_add_angle_component target visibility component)
#     if(NOT TARGET unofficial::angle::${component})
#         find_package(unofficial-angle REQUIRED CONFIG)
#     endif()
#     target_link_libraries(${target} ${visibility} unofficial::angle::${component})
#     # For some stupid reason, ANGLE package puts GLES2 headers into ANGLE subdirectory. Add it to include paths.
#     get_target_property(${component}_INCLUDE_DIRS unofficial::angle::${component} INTERFACE_INCLUDE_DIRECTORIES)
#     foreach(dir ${${component}_INCLUDE_DIRS})
#         target_include_directories(${target} PRIVATE "${dir}/ANGLE")
#     endforeach()
#     # For some another stupid reason, ANGLE package is missing KHR/khrplatform.h. Get it from another package.
#     if(EGL_INCLUDE_DIR)
#         target_include_directories(${target} PRIVATE "${EGL_INCLUDE_DIR}")
#     endif()
# endmacro()

function(myci_add_target_external_dependencies target visibility)
    foreach(dep ${ARGN})
        # TODO: remove commented code
        # # special case to use ANGLE on Win32 for GLESv2
        # if(WIN32 AND "${dep}" STREQUAL "GLESv2")
        #     myci_add_angle_component(${target} ${visibility} libGLESv2)
        #     continue()
        # elseif(WIN32 AND "${dep}" STREQUAL "EGL")
        #     myci_add_angle_component(${target} ${visibility} libEGL)
        #     continue()
        # endif()
        # # default case
        # if(NOT TARGET ${dep}::${dep})
        #     find_package(${dep} REQUIRED)
        # endif()
        # target_link_libraries(${target} ${visibility} ${dep}::${dep})
        target_link_libraries(${target} ${visibility} ${dep})
    endforeach()
endfunction()

####
# @brief Declare library.
# @param name - library name.
# @param SOURCES <file1> [<file2> ...] - list of source files. Required.
# @param RESOURCES <file1> [<file2> ...] - TODO: write description. Optional.
# @param DEPENDENCIES <package1> [<package2> ...] - list of dependency packages. Optional.
#                     These will be searched with find_package(<package> CONFIG REQUIRED).
#                     Passed to target_link_libraries() as <package>::<package>.
# @param EXTERNAL_DEPENDENCIES <target1> [<target2> ...] - list of external dependency targets. Optional.
#                              These will NOT be searched with find_package().
#                              Passed to target_link_libraries() as is.
# @param PUBLIC_COMPILE_DEFINITIONS <def1> [<def2> ...] - TODO: write description. Optional.
# @param PRIVATE_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - private include directories. Optional.
#                                    These directories will not be propagated to the library users.
# @param PUBLIC_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - public include directories. Optional.
#                                    These directories will be propagated to the library users.
# @param INSTALL_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - directories to install headers from. Optional.
#                                    Hierarchy of subdirectories is preserved during isntallation.
#                                    The last directory level will be included in the installation,
#                                    e.g. for '../src/mylib' the destination will be '<system-include-dir>/mylib/'.
function(myci_declare_library name)
    set(options)
    # set(single INSTALL)
    set(multiple SOURCES RESOURCES DEPENDENCIES EXTERNAL_DEPENDENCIES PUBLIC_COMPILE_DEFINITIONS
        PRIVATE_INCLUDE_DIRECTORIES PUBLIC_INCLUDE_DIRECTORIES INSTALL_INCLUDE_DIRECTORIES)
    cmake_parse_arguments(dl "${options}" "${single}" "${multiple}" ${ARGN})

    myci_get_install_flag(install)

    # Normally we create STATIC libraries and specify PUBLIC includes and dependencies.
    # For libraries with no source files this won't work, so use INTERFACE/INTERFACE instead.
    set(public INTERFACE)
    set(static INTERFACE)
    foreach(src ${dl_SOURCES})
        get_filename_component(ext "${src}" LAST_EXT)
        # TODO: why support .cc?
        if("${ext}" STREQUAL ".c" OR "${ext}" STREQUAL ".cpp" OR "${ext}" STREQUAL ".cc")
            set(public PUBLIC)
            set(static STATIC)
            break()
        endif()
    endforeach()

    add_library(${name} ${static} ${dl_SOURCES} ${dl_RESOURCES})

    # TODO: allow specifying the C++ standard as argument
    target_compile_features(${name} ${public} cxx_std_20)
    set_target_properties(${name} PROPERTIES CXX_STANDARD_REQUIRED ON)
    set_target_properties(${name} PROPERTIES CXX_EXTENSIONS OFF)

    foreach(def ${dl_PUBLIC_COMPILE_DEFINITIONS})
        target_compile_definitions(${name} ${public} ${def})
    endforeach()

    foreach(dir ${dl_PUBLIC_INCLUDE_DIRECTORIES})
        # absolute path is needed by target_include_directories()
        file(REAL_PATH
            # PATH
                "${dir}"
            # OUTPUT
                abs_path_directory
            BASE_DIRECTORY
                ${CMAKE_CURRENT_LIST_DIR}
            EXPAND_TILDE
        )
        target_include_directories(${name} ${public} $<BUILD_INTERFACE:${abs_path_directory}>)
    endforeach()

    foreach(dir ${dl_PRIVATE_INCLUDE_DIRECTORIES})
        # absolute path is needed by target_include_directories()
        file(REAL_PATH
            # PATH
                "${dir}"
            # OUTPUT
                abs_path_directory
            BASE_DIRECTORY
                ${CMAKE_CURRENT_LIST_DIR}
            EXPAND_TILDE
        )
        target_include_directories(${name} PRIVATE $<BUILD_INTERFACE:${abs_path_directory}>)
    endforeach()

    myci_add_target_dependencies(${name} ${public} ${dl_DEPENDENCIES})
    myci_add_target_external_dependencies(${name} ${public} ${dl_EXTERNAL_DEPENDENCIES})

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
endfunction()

function(myci_declare_application name)
    set(options)
    set(single)
    set(multiple SOURCES INCLUDE_DIRECTORIES LINK_LIBRARIES DEPENDENCIES EXTERNAL_DEPENDENCIES)
    cmake_parse_arguments(dl "${options}" "${single}" "${multiple}" ${ARGN})

    add_executable(${name} ${dl_SOURCES})
    target_compile_features(${name} PRIVATE cxx_std_20)

    set_target_properties(${name} PROPERTIES
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        VS_DEBUGGER_WORKING_DIRECTORY "${myci_exe_output_dir}/$<CONFIG>"
        RUNTIME_OUTPUT_DIRECTORY "${myci_exe_output_dir}"
    )

    foreach(dir ${dl_INCLUDE_DIRECTORIES})
        target_include_directories(${name} PRIVATE "${dir}")
    endforeach()

    foreach(lib ${dl_LINK_LIBRARIES})
        target_link_libraries(${name} PRIVATE "${lib}")
    endforeach()

    myci_add_target_dependencies(${name} PRIVATE ${dl_DEPENDENCIES})
    myci_add_target_external_dependencies(${name} PRIVATE ${dl_EXTERNAL_DEPENDENCIES})
endfunction()
