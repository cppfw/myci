if(MYCI_MODULE_INCLUDED)
    return()
endif()
set(MYCI_MODULE_INCLUDED TRUE)

include(GNUInstallDirs)

set(myci_private_output_dir "${CMAKE_BINARY_DIR}/out")

####
# @brief Get install flag for current project.
# Checks if <UPPERCASE_PROJECT_NAME>_DISABLE_INSTALL variable is defined and if it is TRUE then sets ${var} to FALSE,
# otherwise sets ${var} to TRUE.
# In case the <UPPERCASE_PROJECT_NAME>_DISABLE_INSTALL is not defined, then checks value of MYCI_GLOBAL_DISABLE_INSTALL
# variable, if it is true then sets ${var} to FALSE, otherwise sets ${var} to TRUE.
# @param var - variable name to store the flag value to.
function(myci_private_get_install_flag var)
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
#                 Defaults to '*.cpp *.c *.hpp *.hxx *.h'.
function(myci_add_source_files out)
    set(options RECURSIVE)
    set(single DIRECTORY)
    set(multiple PATTERNS)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_DIRECTORY)
        message(FATAL_ERROR "myci_add_source_files(): required argument DIRECTORY is empty")
    endif()

    if(NOT arg_PATTERNS)
        list(APPEND arg_PATTERNS "*.cpp" "*.c" "*.hpp" "*.hxx" "*.h")
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

function(myci_private_add_target_dependencies target visibility)
    foreach(dep ${ARGN})
        string(FIND ${dep} "::" colon_colon_pos)
        if(colon_colon_pos EQUAL -1)
            # prefer non-namespaced dependency
            if(TARGET ${dep})
                set(actual_dep ${dep})
            else()
                # package name same as target name
                if(NOT TARGET ${dep}::${dep})
                    find_package(${dep} CONFIG REQUIRED)
                endif()
                set(actual_dep ${dep}::${dep})
            endif()
            target_link_libraries(${target} ${visibility} ${actual_dep})
        else()
            # dep is in <pkg>::<target> format
            if(NOT TARGET ${dep})
                string(SUBSTRING ${dep} 0 ${colon_colon_pos} package_name)
                find_package(${package_name} CONFIG REQUIRED)
            endif()
            target_link_libraries(${target} ${visibility} ${dep})
        endif()
    endforeach()
endfunction()

function(myci_private_add_target_external_dependencies target visibility)
    foreach(dep ${ARGN})
        target_link_libraries(${target} ${visibility} ${dep})
    endforeach()
endfunction()

function(myci_private_copy_resource_file_command out src_dir file)
    get_filename_component(dirname "${src_dir}" NAME)

    set(outfile "${myci_private_output_dir}/${dirname}/${file}")

    # stuff for Visual Studio
    get_filename_component(path "${dirname}/${file}" DIRECTORY)
    string(REPLACE "/" "\\" path "Generated Files/${path}")
    source_group("${path}" FILES "${outfile}")

    file(REAL_PATH
        # PATH
            "${src_dir}/${file}"
        # OUTPUT
            abs_src_file
        BASE_DIRECTORY
            ${CMAKE_CURRENT_LIST_DIR}
        EXPAND_TILDE
    )

    add_custom_command(
        OUTPUT
            "${outfile}"
        COMMAND
            "${CMAKE_COMMAND}" -E copy ${abs_src_file} "${outfile}"
        DEPENDS
            "${src_file}"
        MAIN_DEPENDENCY
            "${src_file}"
    )

    set(${out} ${outfile} PARENT_SCOPE)
endfunction()

####
# @brief Declare resource pack.
# Declare a resource pack target which will copy the resources directory to an application output directory.
# @param target_name - resource pack target name.
# @param DIRECTORY <dir> - directory containing the resources pack. The directory will be copied to application output directory.
function(myci_private_declare_resource_pack target_name)
    set(options)
    set(single DIRECTORY)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_DIRECTORY)
        message(FATAL_ERROR "myci_private_declare_resource_pack(): required argument DIRECTORY is empty")
    endif()

    if(NOT IS_ABSOLUTE ${arg_DIRECTORY})
        message(FATAL_ERROR "myci_private_declare_resource_pack(): DIRECTORY must be an absolute path, got ${arg_DIRECTORY}")
    endif()

    file(
        GLOB_RECURSE
            res_files
        # If arg_DIRECTORY is relative and has '..' in front then this does not work.
        # So, use absoulte directory path.
        RELATIVE
            ${arg_DIRECTORY}
        FOLLOW_SYMLINKS
        CONFIGURE_DEPENDS
        LIST_DIRECTORIES
            false
        "${arg_DIRECTORY}/*"
    )

    set(out_files)
    foreach(file ${res_files})
        # stuff for Visual Studio
        get_filename_component(path "${file}" DIRECTORY)
        string(REPLACE "/" "\\" path "Resource Files/${path}")
        source_group("${path}" FILES "${arg_DIRECTORY}/${file}")

        myci_private_copy_resource_file_command(outfile "${arg_DIRECTORY}" "${file}")
        list(APPEND out_files ${outfile})
    endforeach()

    add_custom_target(${target_name}
        DEPENDS
            ${out_files}
    )
    set_target_properties(${target_name} PROPERTIES FOLDER "CMake")
endfunction()

####
# @brief Generate .cmake file which sets cusotom properties on specified targets.
# The generated .cmake file will have ${PROJECT_NAME}-properties.cmake name.
# @param TARGETS - list of targets to export properties for. The targets will be searched in ${PROJECT_NAME} namespace.
# @param PROPERTIES - list of custom properties to export.
function(myci_private_export_custom_target_properties)
    set(options)
    set(single)
    set(multiple
        TARGETS
        PROPERTIES
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(filename "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-properties.cmake")

    file(WRITE "${filename}" "# Set exported custom properties on imported targets\n")

    foreach(target ${arg_TARGETS})
        foreach(prop ${arg_PROPERTIES})
            get_target_property(val "${target}" "${prop}")
            if(NOT val STREQUAL "val-NOTFOUND")
                file(APPEND "${filename}" 
                    "set_target_properties(${PROJECT_NAME}::${target} PROPERTIES ${prop} \"${val}\")\n"
                )
            endif()
        endforeach()
    endforeach()

    install(
        FILES
            "${filename}"
        DESTINATION
            "${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}"
    )
endfunction()

function(myci_private_generate_config_file)
    set(filename "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config.cmake")

    file(WRITE "${filename}"
        "# Auto-generated\n"
        "include(\"\${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}-targets.cmake\")\n"
        "include(\"\${CMAKE_CURRENT_LIST_DIR}/${PROJECT_NAME}-properties.cmake\")\n"
    )

    install(
        FILES
            "${filename}"
        DESTINATION
            "${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}"
    )
endfunction()


####
# @brief Export targets.
# Generates and installs ${PROJECT_NAME}-config.cmake file for given targets.
# Exported targets are appended with ${PROJECT_NAME}:: namespace.
# @param TARGETS <targte1> [<target2> ...] - list of targets to export.
function(myci_export)
    set(options)
    set(single)
    set(multiple TARGETS)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    myci_private_get_install_flag(install)
    if(${install})
        # assign targets to export name
        install(
            TARGETS
                ${arg_TARGETS}
            EXPORT
                ${PROJECT_NAME}-export
        )
        # generate and install cmake import targets file
        install(
            EXPORT
                ${PROJECT_NAME}-export
            FILE
                ${PROJECT_NAME}-targets.cmake
            DESTINATION
                "${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}"
            NAMESPACE
                "${PROJECT_NAME}::"
        )

        myci_private_export_custom_target_properties(
            TARGETS
                ${arg_TARGETS}
            PROPERTIES
                myci_installed_resource_directory_within_datadir
        )

        myci_private_generate_config_file()
    endif()
endfunction()

####
# @brief Declare library.
# A target alias will be added as add_library(${PROJECT_NAME}::${name} ALIAS ${name}).
# By default it will also export the library as package with same name. Exporting can be suppressed using NO_EXPORT option.
# @param name - library name.
# @param SOURCES <file1> [<file2> ...] - list of source files. Required.
# @param RESOURCE_DIRECTORY <dir> - directory with resource files. Optional. The directory will be installed.
#                                   Application linking to the library will also copy the resources directory to the
#                                   application binary output directory.
# @param DEPENDENCIES <dep1> [<dep2> ...] - list of dependencies. Optional.
#                     If <depX> does not have any '::' in its name, then
#                     it will be searched with find_package(<depX> CONFIG REQUIRED) and
#                     passed to target_link_libraries() as <depX>::<depX>.
#                     If <depX> is in format '<pkg>::<name>' then the <pkg> namespace is treated as package name,
#                     it will be searched with find_package(<pkg> CONFIG REQUIRED) and
#                     the target will be passed to target_link_libraries() as <depX>.
# @param EXTERNAL_DEPENDENCIES <target1> [<target2> ...] - list of external dependency targets. Optional.
#                              These will NOT be searched with find_package().
#                              Passed to target_link_libraries() as is.
# @param PUBLIC_COMPILE_DEFINITIONS <def1> [<def2> ...] - preprocessor macro definitions. Optional.
# @param PRIVATE_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - private include directories. Optional.
#                                    These directories will not be propagated to the library users.
# @param PUBLIC_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - public include directories. Optional.
#                                    These directories will be propagated to the library users.
# @param INSTALL_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - directories to install headers from. Optional.
#                                    Hierarchy of subdirectories is preserved during isntallation.
#                                    The last directory level will be included in the installation,
#                                    e.g. for '../src/mylib' the destination will be '<system-include-dir>/mylib/'.
# @param IDE_FOLDER IDE folder for the library (default is "Libs")
function(myci_declare_library name)
    set(options NO_EXPORT)
    set(single IDE_FOLDER)
    set(multiple
        SOURCES
        RESOURCE_DIRECTORY
        DEPENDENCIES
        EXTERNAL_DEPENDENCIES
        PUBLIC_COMPILE_DEFINITIONS
        PRIVATE_INCLUDE_DIRECTORIES
        PUBLIC_INCLUDE_DIRECTORIES
        INSTALL_INCLUDE_DIRECTORIES
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    # Normally we create STATIC libraries and specify PUBLIC includes and dependencies.
    # For libraries with no source files this won't work, so use INTERFACE/INTERFACE instead.
    set(public INTERFACE)
    set(static INTERFACE)
    foreach(src ${arg_SOURCES})
        get_filename_component(ext "${src}" LAST_EXT)
        # TODO: why support .cc?
        if("${ext}" STREQUAL ".c" OR "${ext}" STREQUAL ".cpp" OR "${ext}" STREQUAL ".cc")
            set(public PUBLIC)
            set(static STATIC)
            break()
        endif()
    endforeach()

    add_library(${name} ${static} ${arg_SOURCES})
    add_library(${PROJECT_NAME}::${name} ALIAS ${name})

    if(NOT arg_IDE_FOLDER)
        set(arg_IDE_FOLDER "Libs")
    endif()
    set_target_properties(${name} PROPERTIES FOLDER "${arg_IDE_FOLDER}")

    # TODO: allow specifying the C++ standard as argument
    target_compile_features(${name} ${public} cxx_std_20)
    set_target_properties(${name} PROPERTIES CXX_STANDARD_REQUIRED ON)
    set_target_properties(${name} PROPERTIES CXX_EXTENSIONS OFF)

    foreach(def ${arg_PUBLIC_COMPILE_DEFINITIONS})
        target_compile_definitions(${name} ${public} ${def})
    endforeach()

    foreach(dir ${arg_PUBLIC_INCLUDE_DIRECTORIES})
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

    foreach(dir ${arg_PRIVATE_INCLUDE_DIRECTORIES})
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

    myci_private_add_target_dependencies(${name} ${public} ${arg_DEPENDENCIES})
    myci_private_add_target_external_dependencies(${name} ${public} ${arg_EXTERNAL_DEPENDENCIES})

    if(arg_RESOURCE_DIRECTORY)
        file(REAL_PATH
            # PATH
                "${arg_RESOURCE_DIRECTORY}"
            # OUTPUT
                abs_path_directory
            BASE_DIRECTORY
                ${CMAKE_CURRENT_LIST_DIR}
            EXPAND_TILDE
        )

        get_filename_component(dirname "${arg_RESOURCE_DIRECTORY}" NAME)

        set_target_properties(${name}
            PROPERTIES
                myci_resource_directory "${abs_path_directory}"
                myci_installed_resource_directory_within_datadir "${PROJECT_NAME}/${dirname}"
        )
    endif()

    myci_private_get_install_flag(install)
    if(${install})
        target_include_directories(${name} ${public} $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
        # install library header files preserving directory hierarchy
        foreach(dir ${arg_INSTALL_INCLUDE_DIRECTORIES})
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

        if(${arg_RESOURCE_DIRECTORY})
            install(
                DIRECTORY
                    "${arg_RESOURCE_DIRECTORY}"
                DESTINATION
                    "${CMAKE_INSTALL_DATAROOTDIR}/${PROJECT_NAME}"
            )
        endif()

        if(NOT arg_NO_EXPORT)
            myci_export(
                TARGETS
                    ${name}
            )
        endif()
    endif()
endfunction()

function(myci_private_get_all_dependencies out)
    set(options)
    set(single TARGET)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    get_target_property(interface_deps ${arg_TARGET} INTERFACE_LINK_LIBRARIES)
    get_target_property(link_deps ${arg_TARGET} LINK_LIBRARIES)

    set(all_deps)
    if(NOT interface_deps STREQUAL "interface_deps-NOTFOUND")
        list(APPEND all_deps ${interface_deps})
    endif()
    if(NOT link_deps STREQUAL "link_deps-NOTFOUND")
        list(APPEND all_deps ${link_deps})
    endif()

    foreach(dep ${all_deps})
        if(NOT TARGET ${dep})
            continue()
        endif()

        myci_private_get_all_dependencies(out_deps
            TARGET
                ${dep}
        )
        foreach(out_dep ${out_deps})
            if(NOT "${out_dep}" IN_LIST all_deps)
                if(TARGET ${out_dep})
                    list(APPEND all_deps ${out_dep})
                endif()
            endif()
        endforeach()
    endforeach()
    set(${out} ${all_deps} PARENT_SCOPE)
endfunction()

# Generate a resouce copying target for each target from DEPENDENCIES
# and add the generated target as dependency to the TARGET.
function(myci_private_add_resource_pack_deps)
    set(options)
    set(single TARGET)
    set(multiple DEPENDENCIES)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    foreach(dep ${arg_DEPENDENCIES})
        string(REPLACE "::" "___" res_target_name "${dep}")
        set(res_target_name ${res_target_name}__copy_resources)

        if(TARGET ${res_target_name})
            add_dependencies(${arg_TARGET} ${res_target_name})
            continue()
        endif()

        get_target_property(res_dir "${dep}" myci_resource_directory)
        if(NOT res_dir STREQUAL "res_dir-NOTFOUND")
            if(NOT IS_ABSOLUTE ${res_dir})
                message(FATAL_ERROR "myci_private_add_resource_pack_deps(): myci_resource_directory property must be an absolute path, got ${res_dir}")
            endif()

            myci_private_declare_resource_pack(${res_target_name}
                DIRECTORY
                    ${res_dir}
            )
            add_dependencies(${arg_TARGET} ${res_target_name})
        else()
            get_target_property(res_dir "${dep}" myci_installed_resource_directory_within_datadir)
            if(NOT res_dir STREQUAL "res_dir-NOTFOUND")
                file(REAL_PATH
                    # PATH
                        "${res_dir}"
                    # OUTPUT
                        abs_path_directory
                    BASE_DIRECTORY
                        "${CMAKE_INSTALL_FULL_DATAROOTDIR}"
                    EXPAND_TILDE
                )

                myci_private_declare_resource_pack(${res_target_name}
                    DIRECTORY
                        ${abs_path_directory}
                )
                add_dependencies(${arg_TARGET} ${res_target_name})
            endif()
        endif()
    endforeach()
endfunction()


####
# @brief Declare application.
# @param name - application name.
# @param SOURCES <file1> [<file2> ...] - list of source files. Required.
# @param RESOURCE_DIRECTORY <dir> - application resource directory. The resource directory will be copied to the
#                                   application binary output directory.
# @param DEPENDENCIES <dep1> [<dep2> ...] - list of dependencies. Optional.
#                     If <depX> does not have any '::' in its name, then
#                     it will be searched with find_package(<depX> CONFIG REQUIRED) and
#                     passed to target_link_libraries() as <depX>::<depX>.
#                     If <depX> is in format '<pkg>::<name>' then the <pkg> namespace is treated as package name,
#                     it will be searched with find_package(<pkg> CONFIG REQUIRED) and
#                     the target will be passed to target_link_libraries() as <depX>.
# @param EXTERNAL_DEPENDENCIES <target1> [<target2> ...] - list of external dependency targets. Optional.
#                              These will NOT be searched with find_package().
#                              Passed to target_link_libraries() as is.
# @param INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - include directories. Optional.
# @param GUI - the application is a GUI application, i.e. not a console application.
#              This option only has effect on Windows, on other systems it has no effect.
#              On Windows, inidcates that a generated application will provide WinMain() function instead of main() as entry point.
function(myci_declare_application name)
    set(options GUI)
    set(single RESOURCE_DIRECTORY)
    set(multiple
        SOURCES
        INCLUDE_DIRECTORIES
        DEPENDENCIES
        EXTERNAL_DEPENDENCIES
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(win32)
    if(WIN32)
        if(arg_GUI)
            set(win32 WIN32)
        endif()
    endif()

    add_executable(${name} ${win32} ${arg_SOURCES})
    target_compile_features(${name} PRIVATE cxx_std_20)

    set_target_properties(${name} PROPERTIES
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        VS_DEBUGGER_WORKING_DIRECTORY "${myci_private_output_dir}"
        RUNTIME_OUTPUT_DIRECTORY "${myci_private_output_dir}"
    )

    foreach(dir ${arg_INCLUDE_DIRECTORIES})
        target_include_directories(${name} PRIVATE "${dir}")
    endforeach()

    foreach(lib ${arg_LINK_LIBRARIES})
        target_link_libraries(${name} PRIVATE "${lib}")
    endforeach()

    myci_private_add_target_dependencies(${name} PRIVATE ${arg_DEPENDENCIES})
    myci_private_add_target_external_dependencies(${name} PRIVATE ${arg_EXTERNAL_DEPENDENCIES})

    # copy direct application resources
    if(arg_RESOURCE_DIRECTORY)
        set(res_target_name ${name}__copy_resources)

        file(REAL_PATH
            # PATH
                "${arg_RESOURCE_DIRECTORY}"
            # OUTPUT
                abs_path_directory
            BASE_DIRECTORY
                ${CMAKE_CURRENT_LIST_DIR}
            EXPAND_TILDE
        )

        myci_private_declare_resource_pack(${res_target_name}
            DIRECTORY
                ${abs_path_directory}
        )
        add_dependencies(${name} ${res_target_name})
    endif()

    # copy resources of linked libraries
    myci_private_get_all_dependencies(all_deps
        TARGET
            ${name}
    )
    myci_private_add_resource_pack_deps(
        TARGET
            ${name}
        DEPENDENCIES
            ${all_deps}
    )
endfunction()
