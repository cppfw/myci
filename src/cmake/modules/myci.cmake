if(MYCI_MODULE_INCLUDED)
    return()
endif()
set(MYCI_MODULE_INCLUDED TRUE)

include(GNUInstallDirs)

set(myci_private_output_dir "${CMAKE_BINARY_DIR}/exe")

# try to find package by config first and if it fails try by module
function(myci_private_find_package package)
    set(options REQUIRED QUIET)
    set(single OUT_IS_FOUND OUT_IS_BY_CONFIG)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    get_property(found_packages GLOBAL PROPERTY myci_found_packages)
    get_property(found_packages_by_config GLOBAL PROPERTY myci_found_packages_by_config)

    if(${package} IN_LIST found_packages)
#        message("myci_private_find_package(): package ${package} already found")
        if(arg_OUT_IS_BY_CONFIG)
            if(${package} IN_LIST found_packages_by_config)
                set(${arg_OUT_IS_BY_CONFIG} True PARENT_SCOPE)
            else()
                unset(${arg_OUT_IS_BY_CONFIG} PARENT_SCOPE)
            endif()
        endif()
        if(arg_OUT_IS_FOUND)
            set(${arg_OUT_IS_FOUND} True PARENT_SCOPE)
        endif()
        return()
    endif()

    set(opts GLOBAL)

    # try config first
    find_package(${package} ${opts} CONFIG QUIET)
    if(NOT ${package}_FOUND)
        if(arg_REQUIRED)
            set(opts ${opts} REQUIRED)
        endif()
        if(arg_QUIET)
            set(opts ${opts} QUIET)
        endif()
        find_package(${package} ${opts} MODULE)
    endif()

    if(${package}_FOUND)
        set_property(GLOBAL APPEND PROPERTY myci_found_packages ${package})

        set(is_found True)

        if(${package}_CONFIG)
            set_property(GLOBAL APPEND PROPERTY myci_found_packages_by_config ${package})
            set(is_by_config True)
        else()
            unset(is_by_config)
        endif()
#        message("myci_private_find_package(): package ${package} found, opts = ${opts}, is_by_config = ${is_by_config}")
    else()
#        message("myci_private_find_package(): package ${package} not found, opts = ${opts}")
        unset(is_found)
        unset(is_by_config)
    endif()

    if(arg_OUT_IS_FOUND)
        if(is_found)
            set(${arg_OUT_IS_FOUND} True PARENT_SCOPE)
        else()
            unset(${arg_OUT_IS_FOUND} PARENT_SCOPE)
        endif()
    endif()

    if(arg_OUT_IS_BY_CONFIG)
        if(is_by_config)
            set(${arg_OUT_IS_BY_CONFIG} True PARENT_SCOPE)
        else()
            unset(${arg_OUT_IS_BY_CONFIG} PARENT_SCOPE)
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
# @param ADDITIONAL_SOURCE_FILE_EXTENSIONS <pattern1> [<pattern2> ...] - list of file extensions
#                 that will be added into generated IDE projects but will not be compiled directly by the compiler.
#                 Example: '.cxx .hxx'. Defaults to '.cxx'.
function(myci_add_source_files out)
    set(options RECURSIVE)
    set(single DIRECTORY)
    set(multiple PATTERNS ADDITIONAL_SOURCE_FILE_EXTENSIONS)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_DIRECTORY)
        message(FATAL_ERROR "myci_add_source_files(): required argument DIRECTORY is empty")
    endif()

    if(NOT arg_PATTERNS)
        list(APPEND arg_PATTERNS "*.cpp" "*.c" "*.hpp" "*.hxx" "*.h")
    endif()

    if(NOT arg_ADDITIONAL_SOURCE_FILE_EXTENSIONS)
        list(APPEND arg_ADDITIONAL_SOURCE_FILE_EXTENSIONS ".cxx")
    endif()

    set(patterns)
    foreach(pattern ${arg_PATTERNS})
        list(APPEND patterns "${arg_DIRECTORY}/${pattern}")
    endforeach()
    foreach(pattern ${arg_ADDITIONAL_SOURCE_FILE_EXTENSIONS})
        list(APPEND patterns "${arg_DIRECTORY}/*${pattern}")
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
        # So, use absolute directory path.
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

        # for additional source files set HEADER_FILE_ONLY property to true to avoid them being picked up by the compiler
        get_filename_component(ext "${file}" EXT)
        list(FIND arg_ADDITIONAL_SOURCE_FILE_EXTENSIONS "${ext}" index)
        if(NOT index EQUAL -1)
            set_source_files_properties("${arg_DIRECTORY}/${file}" PROPERTIES HEADER_FILE_ONLY TRUE)
        endif()

        list(APPEND result_files "${arg_DIRECTORY}/${file}")
    endforeach()

    set(${out} ${${out}} ${result_files} PARENT_SCOPE)
endfunction()

# Append <package>/ to dependencies, where <package> is the package name which is supposed to provide the target.
# PkgConfig dependencies replaced by 'PkgConfig/<pkg-config-lib>'.
function(myci_private_get_full_dependencies out)
    set(options)
    set(single)
    set(multiple DEPENDENCIES)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(result)
    foreach(dep ${arg_DEPENDENCIES})
        set(package_name)

        string(FIND ${dep} "/" slash_pos)
        if(NOT slash_pos EQUAL -1)
            # dep is already in <package>/<target> format
            list(APPEND result ${dep})
            continue()
        else()
            string(FIND ${dep} "::" colon_colon_pos)
            if(colon_colon_pos EQUAL -1)
                set(target_name ${dep}::${dep})
                set(package_name ${dep})
            else()
                # dep is in <pkg>::<target> format

                # set package_name
                string(SUBSTRING ${dep} 0 ${colon_colon_pos} package_name)

                if(${package_name} STREQUAL "PkgConfig")
                    math(EXPR target_pos "${colon_colon_pos}+2")
                    string(SUBSTRING ${dep} ${target_pos} -1 lib_name)
                    set(target_name ${lib_name})
                else()
                    set(target_name ${dep})
                endif()
            endif()
        endif()
        list(APPEND result "${package_name}/${target_name}")
    endforeach()
    set(${out} ${result} PARENT_SCOPE)
endfunction()

function(myci_private_split_by_slash out_left out_right)
    set(options NO_FORMAT_ERROR)
    set(single STR)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})
    
    if(NOT arg_STR)
        message(FATAL_ERROR "myci_private_split_by_slash(): required argument STR is empty")
    endif()

    string(FIND ${arg_STR} "/" slash_pos)
    if(slash_pos EQUAL -1)
        if(arg_NO_FORMAT_ERROR)
            set(${out_left} "" PARENT_SCOPE)
            set(${out_right} "" PARENT_SCOPE)
            return()
        else()
            message(FATAL_ERROR "myci_private_split_by_slash(): STR does not contain: ${arg_STR}")
        endif()
    endif()

    string(SUBSTRING ${arg_STR} 0 ${slash_pos} left_part)

    math(EXPR target_pos "${slash_pos}+1")
    string(SUBSTRING ${arg_STR} ${target_pos} -1 right_part)

    set(${out_left} ${left_part} PARENT_SCOPE)
    set(${out_right} ${right_part} PARENT_SCOPE)
endfunction()

# @return pkg-config lib if the package is a pkg-config package, i.e. in 'PkgConfig/<pkg-config-lib>' format.
# @return empty string if the package is not a pkg-config one. 
function(myci_private_get_lib_of_pkgconfig_package out)
    set(options)
    set(single PACKAGE)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})
    
    if(NOT arg_PACKAGE)
        message(FATAL_ERROR "myci_private_get_lib_of_pkgconfig_package(): required argument PACKAGE is empty")
    endif()

    myci_private_split_by_slash(package_name target_name
        STR
            ${arg_PACKAGE}
        NO_FORMAT_ERROR
    )

    if(NOT ${package_name} STREQUAL "PkgConfig")
        set(${out} "" PARENT_SCOPE)
    else()
        set(${out} ${target_name} PARENT_SCOPE)
    endif()
endfunction()

# get list of packages from list of full dependencies.
# PkgConfig packages are returned in format 'PkgConfig/<pkg-config-lib>'
function(myci_private_get_packages_list out)
    set(options)
    set(single)
    set(multiple FULL_DEPENDENCIES)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(result)
    foreach(dep ${arg_FULL_DEPENDENCIES})
        myci_private_split_by_slash(package_name target_name
            STR
                ${dep}
        )

#        message("package_name = ${package_name}, target_name = ${target_name}")

        if(${package_name} STREQUAL "PkgConfig")
            list(APPEND result "${package_name}/${target_name}")
            continue()
        endif()

        list(APPEND result ${package_name})
    endforeach()
    set(${out} ${result} PARENT_SCOPE)
endfunction()

# Makes sure all the targets are available by finding needed packages.
# Returns list of targets to link to.
function(myci_private_find_packages out_targets)
    set(options)
    set(single)
    set(multiple FULL_DEPENDENCIES)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(result_targets)
    foreach(dep ${arg_FULL_DEPENDENCIES})
        myci_private_split_by_slash(package_name target_name
            STR
                ${dep}
        )

        if(${package_name} STREQUAL "PkgConfig")
            list(APPEND result_targets PkgConfig::${target_name})
            if(TARGET PkgConfig::${target_name})
                continue()
            endif()

            if(NOT PkgConfig_FOUND)
                find_package(PkgConfig REQUIRED)
            endif()
            pkg_check_modules(${target_name} REQUIRED IMPORTED_TARGET "${target_name}")
            continue()
        endif()

        set(original_target ${target_name})
        if(TARGET ${target_name})
            get_target_property(aliased_target ${target_name} ALIASED_TARGET)
            if(aliased_target)
                # The target is an alias.
                # Use aliased target as original target further.
                set(original_target ${aliased_target})
            endif()
        endif()

#        message("myci_private_find_packages(): dep = ${dep}, package_name = ${package_name}, target_name = ${target_name}, original_target = ${original_target}")

        list(APPEND result_targets ${original_target})

        if(TARGET ${original_target})
#            message("myci_private_find_packages(): target ${original_target} already exists")

            get_target_property(imported ${original_target} IMPORTED)
            if(NOT imported)
#                message("myci_private_find_packages(): target ${original_target} is from monorepo")

                # The target is not imported, it means that it comes from monorepo.
                # It means that the package for that target would be imported using
                # the CONFIG method if it was imported from non-monorepo source, e.g. vcpkg,
                # because MODULE method is obsolete and is not supposed to be used in monorepo.
                # So, add the package to the global list of BY-CONFIG found packages for future information,
                # it will be later used for example when generating config cmake file.
                get_property(found_packages_by_config GLOBAL PROPERTY myci_found_packages_by_config)
                if(NOT ${package_name} IN_LIST found_packages_by_config)
#                    message("myci_private_find_packages(): add ${package_name} to global list of config imported packages")
                    set_property(GLOBAL APPEND PROPERTY myci_found_packages_by_config ${package_name})
                endif()
            else()
#                message("myci_private_find_packages(): target ${original_target} is NOT from monorepo")
            endif()

            continue()
        endif()

#        message("myci_private_find_packages(): find package ${package_name}")

        myci_private_find_package(${package_name})

#        message("myci_private_find_packages(): done finding package ${package_name}")

        if(NOT TARGET ${original_target})
            message(FATAL_ERROR "assertion failure: target ${original_target} does not exist")
        endif()
    endforeach()
    set(${out_targets} ${result_targets} PARENT_SCOPE)
endfunction()

function(myci_private_add_target_dependencies)
    set(options)
    set(single
        TARGET
        VISIBILITY
    )
    set(multiple
        DEPENDENCIES
        LINUX_ONLY_DEPENDENCIES
        WINDOWS_ONLY_DEPENDENCIES
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_TARGET)
        message(FATAL_ERROR "myci_private_add_target_dependencies(): required argument TARGET is empty.")
    endif()

    if(NOT arg_VISIBILITY)
        message(FATAL_ERROR "myci_private_add_target_dependencies(): required argument VISIBILITY is empty.")
    endif()

    # all
    myci_private_get_full_dependencies(full_deps
        DEPENDENCIES
            ${arg_DEPENDENCIES}
    )
    myci_private_find_packages(link_targets
        FULL_DEPENDENCIES
            ${full_deps}
    )

    # linux
    set(linux_link_targets)
    myci_private_get_full_dependencies(linux_full_deps
        DEPENDENCIES
            ${arg_LINUX_ONLY_DEPENDENCIES}
    )
    if(LINUX)
        myci_private_find_packages(linux_link_targets
            FULL_DEPENDENCIES
                ${linux_full_deps}
        )
    endif()

    # windows
    set(windows_link_targets)
    myci_private_get_full_dependencies(windows_full_deps
        DEPENDENCIES
            ${arg_WINDOWS_ONLY_DEPENDENCIES}
    )
    if(WIN32)
        myci_private_find_packages(windows_link_targets
            FULL_DEPENDENCIES
                ${windows_full_deps}
        )
    endif()

    set_target_properties(${arg_TARGET}
        PROPERTIES
            myci_full_dependencies "${full_deps}"
            myci_linux_full_dependencies "${linux_full_deps}"
            myci_windows_full_dependencies "${windows_full_deps}"
    )

    # TODO: is this 'if' needed? can we call target_link_libraries() with empty list of link targets? If no, then also check for ${linux_link_targets} ${windows_link_targets} 
    if(link_targets)
        target_link_libraries(${arg_TARGET} ${arg_VISIBILITY} ${link_targets} ${linux_link_targets} ${windows_link_targets})
    endif()
endfunction()

# TODO: make this function arguments named
function(myci_private_copy_resource_file_command out target_name src_dir file)
    get_filename_component(dirname "${src_dir}" NAME)

    set(outfile "${myci_private_output_dir}/${target_name}/${dirname}/${file}")

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
# @param APP_TARGET <name> - application target name. Resources are copied to the application output directory, so the application
#                            target name will be used as a subdirectory to which the resources are copied.
# @param DIRECTORY <dir> - directory containing the resources pack. The directory will be copied to application output directory.
function(myci_private_declare_resource_pack target_name)
    set(options)
    set(single
        APP_TARGET
        DIRECTORY
    )
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_APP_TARGET)
        message(FATAL_ERROR "myci_private_declare_resource_pack(): required argument APP_TARGET is empty")
    endif()

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

        myci_private_copy_resource_file_command(outfile "${arg_APP_TARGET}" "${arg_DIRECTORY}" "${file}")
        list(APPEND out_files ${outfile})
    endforeach()

    add_custom_target(${target_name}
        DEPENDS
            ${out_files}
    )
    set_target_properties(${target_name} PROPERTIES FOLDER "CMake")
endfunction()

####
# @brief Generate .cmake file which sets custom properties on specified targets.
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

    file(WRITE "${filename}"
        "# Set exported custom properties on imported targets\n"
    )

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

function(myci_private_write_find_packages_to_config_file)
    set(options)
    set(single FILENAME)
    set(multiple PACKAGES)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_FILENAME)
        message(FATAL_ERROR "myci_private_write_find_packages_to_config_file(): required argument FILENAME is empty")
    endif()

    set(pkg_config_encountered)
    foreach(pkg ${arg_PACKAGES})
        myci_private_get_lib_of_pkgconfig_package(pkg_config_lib
            PACKAGE
                ${pkg}
        )

        if(pkg_config_lib)
            # pkg-config package
            if(NOT pkg_config_encountered)
                file(APPEND "${arg_FILENAME}"
                    "find_dependency(PkgConfig REQUIRED)\n"
                )
                set(pkg_config_encountered True)
            endif()
            file(APPEND "${filename}"
                "if(NOT TARGET PkgConfig::${pkg_config_lib})\n"
                "    pkg_check_modules(${pkg_config_lib} REQUIRED IMPORTED_TARGET \"${pkg_config_lib}\")\n"
                "endif()\n"
            )
        else()
            # non-pkg-config package

#            message("myci_private_write_find_packages_to_config_file(): pkg = ${pkg}")

            # At the time this function is called all the packages should already have been found.
            # So, we can get information about the package finding method from the
            # global myci_found_packages_by_config list.
            get_property(found_packages_by_config GLOBAL PROPERTY myci_found_packages_by_config)
            if(${pkg} IN_LIST found_packages_by_config)
#                message("myci_private_write_find_packages_to_config_file(): package ${pkg} found by config")
                file(APPEND "${arg_FILENAME}"
                    "find_dependency(${pkg} CONFIG)\n"
                )
            else()
#                message("myci_private_write_find_packages_to_config_file(): package ${pkg} found by module")
                file(APPEND "${arg_FILENAME}"
                    "find_dependency(${pkg})\n"
                )
            endif()
        endif()
    endforeach()
endfunction()

function(myci_private_generate_config_file)
    set(options)
    set(single)
    set(multiple
        TARGETS
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(all_full_deps)
    set(all_linux_full_deps)
    set(all_windows_full_deps)

    # collect full deps
    foreach(target ${arg_TARGETS})
        get_target_property(full_deps ${target} myci_full_dependencies)
        get_target_property(linux_full_deps ${target} myci_linux_full_dependencies)
        get_target_property(windows_full_deps ${target} myci_windows_full_dependencies)

        foreach(dep ${full_deps})
            if(NOT ${dep} IN_LIST all_full_deps)
                list(APPEND all_full_deps ${dep})
            endif()
        endforeach()

        foreach(dep ${linux_full_deps})
            if(NOT ${dep} IN_LIST all_linux_full_deps)
                list(APPEND all_linux_full_deps ${dep})
            endif()
        endforeach()

        foreach(dep ${windows_full_deps})
            if(NOT ${dep} IN_LIST all_windows_full_deps)
                list(APPEND all_windows_full_deps ${dep})
            endif()
        endforeach()
    endforeach()
    
#    message("all_full_deps = ${all_full_deps}")

    myci_private_get_packages_list(packages
        FULL_DEPENDENCIES
            ${all_full_deps}
    )
    myci_private_get_packages_list(linux_packages
        FULL_DEPENDENCIES
            ${all_linux_full_deps}
    )
    myci_private_get_packages_list(windows_packages
        FULL_DEPENDENCIES
            ${all_windows_full_deps}
    )

#    message("packages = ${packages}")

    set(filename "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config.cmake")

    file(WRITE "${filename}"
        "# Auto-generated\n\n"
        "include(CMakeFindDependencyMacro)\n\n"
    )

    # Config file should find_package() for all the dependencies, so
    # here we generate code for finding all direct dependency packages.

    myci_private_write_find_packages_to_config_file(
        FILENAME
            "${filename}"
        PACKAGES
            ${packages}
    )
    file(APPEND "${filename}" "\n")

    if(linux_packages)
        file(APPEND "${filename}"
            "if(LINUX)\n"
        )
        myci_private_write_find_packages_to_config_file(
            FILENAME
                "${filename}"
            PACKAGES
                ${linux_packages}
        )
        file(APPEND "${filename}"
            "endif()\n"
        )
        file(APPEND "${filename}" "\n")
    endif()

    if(windows_packages)
        file(APPEND "${filename}"
            "if(WIN32)\n"
        )
        myci_private_write_find_packages_to_config_file(
            FILENAME
                "${filename}"
            PACKAGES
                ${windows_packages}
        )
        file(APPEND "${filename}"
            "endif()\n"
        )
        file(APPEND "${filename}" "\n")
    endif()

    # Done generating find_package() code.

    file(APPEND "${filename}"
        "\n"
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

    myci_private_generate_config_file(
        TARGETS
            ${arg_TARGETS}
    )
endfunction()

####
# @brief Declare library.
# A target alias will be added as add_library(${PROJECT_NAME}::${name} ALIAS ${name}).
# By default it will also export the library as package with same name. Exporting can be suppressed using NO_EXPORT option.
# @param name - library name.
# @param SOURCES <file1> [<file2> ...] - list of source files. Required.
# @param RESOURCE_DIRECTORY <dir> - directory with resource files. Optional. The directory will be installed.
#                           Application linking to the library will also copy the resources directory to the
#                           application binary output directory.
# @param DEPENDENCIES <dep1> [<dep2> ...] - list of dependencies. Optional.
#                     If <depX> does not have any '::' in its name, then
#                     it will be searched with find_package(<depX> CONFIG) and if not found then searched with find_package(<depX> MODULE REQUIRED),
#                     and passed to target_link_libraries() as <depX>::<depX>.
#                     If <depX> is in format '<pkg>::<name>' then the <pkg> namespace is treated as package name,
#                     it will be searched with find_package(<pkg> CONFIG) and if not found then searched with find_package(<pkg> MODULE REQUIRED),
#                     and the target will be passed to target_link_libraries() as <depX>.
#                     If <depX> is in format '<pkg>/<target>' then
#                     it will be searched with find_package(<pkg> CONFIG) and if not found then searched with find_package(<pkg> MODULE REQUIRED),
#                     and the target will be passed to target_link_libraries() as <target>.
#                     If <depX> is in format 'PkgConfig::<target>' then
#                     PkgConfig package will be searched with find_package(PkgConfig REQUIRED) and
#                     the target will be added as pkg_check_modules(<target> REQUIRED IMPORTED_TARGET "<target>").
# @param LINUX_ONLY_DEPENDENCIES <dep1> [<dep2> ...] - list of linux-specific dependencies. Optional. Same rules as for DEPENDENCIES apply.
# @param WINDOWS_ONLY_DEPENDENCIES <dep1> [<dep2> ...] - list of windows-specific dependencies. Optional. Same rules as for DEPENDENCIES apply.
# @param PRIVATE_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - private include directories. Optional.
#                                    These directories will not be propagated to the library users.
# @param PUBLIC_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - public include directories. Optional.
#                                    These directories will be propagated to the library users.
# @param INSTALL_INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - directories to install headers from. Optional.
#                                    Hierarchy of subdirectories is preserved during installation.
#                                    The last directory level will be included in the installation,
#                                    e.g. for '../src/mylib' the destination will be '<system-include-dir>/mylib/'.
# @param IDE_FOLDER - folder in the generated IDE project for the library. Optional. Defaults to "Libs".
# @param PREPROCESSOR_DEFINITIONS [<def1>[=<val1>] ...] - preprocessor macro definitions. Optional.
function(myci_declare_library name)
    set(options NO_EXPORT)
    set(single
        IDE_FOLDER
        RESOURCE_DIRECTORY
    )
    set(multiple
        SOURCES
        DEPENDENCIES
        LINUX_ONLY_DEPENDENCIES
        WINDOWS_ONLY_DEPENDENCIES
        PRIVATE_INCLUDE_DIRECTORIES
        PUBLIC_INCLUDE_DIRECTORIES
        INSTALL_INCLUDE_DIRECTORIES
        PREPROCESSOR_DEFINITIONS
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    # Normally we create STATIC libraries and specify PUBLIC includes and dependencies.
    # For libraries with no source files this won't work, so use INTERFACE/INTERFACE instead.
    set(public INTERFACE)
    set(private INTERFACE)
    set(static INTERFACE)
    foreach(src ${arg_SOURCES})
        get_filename_component(ext "${src}" LAST_EXT)
        if("${ext}" STREQUAL ".c" OR "${ext}" STREQUAL ".cpp" OR "${ext}" STREQUAL ".cc")
            set(public PUBLIC)
            set(private PRIVATE)
            set(static STATIC)
            break()
        endif()
    endforeach()

    add_library(${name} ${static} ${arg_SOURCES})
    add_library(${PROJECT_NAME}::${name} ALIAS ${name})

    # define DEBUG macro for Debug build configuration
    target_compile_definitions(${name} ${private} $<$<CONFIG:Debug>:DEBUG>)

    if(NOT arg_IDE_FOLDER)
        set(arg_IDE_FOLDER "Libs")
    endif()
    set_target_properties(${name} PROPERTIES FOLDER "${arg_IDE_FOLDER}")

    # TODO: allow specifying the C++ standard as argument
    target_compile_features(${name} ${public} cxx_std_20)
    set_target_properties(${name} PROPERTIES CXX_STANDARD_REQUIRED ON)
    set_target_properties(${name} PROPERTIES CXX_EXTENSIONS OFF)

    # force unicode character set under Visual Studio
    target_compile_definitions(${name} ${private} _UNICODE)

    # tell MSVC compiler that sources are in utf-8 encoding
    if (MSVC)
        target_compile_options(${name} ${private} "$<$<C_COMPILER_ID:MSVC>:/utf-8>")
        target_compile_options(${name} ${private} "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
    endif()

    target_compile_definitions(${name} ${private} ${arg_PREPROCESSOR_DEFINITIONS})

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
        target_include_directories(${name} ${private} $<BUILD_INTERFACE:${abs_path_directory}>)
    endforeach()

    myci_private_add_target_dependencies(
        TARGET
            ${name}
        VISIBILITY
            ${public}
        DEPENDENCIES
            ${arg_DEPENDENCIES}
        LINUX_ONLY_DEPENDENCIES
            ${arg_LINUX_ONLY_DEPENDENCIES}
        WINDOWS_ONLY_DEPENDENCIES
            ${arg_WINDOWS_ONLY_DEPENDENCIES}
    )

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
                myci_installed_resource_directory_within_datadir "\${CMAKE_CURRENT_LIST_DIR}/${dirname}"
        )
    endif()

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
                PATTERN "*.hh"
        )
    endforeach()

    if(arg_RESOURCE_DIRECTORY)
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
endfunction()

####
# @brief Recursively get all dependencies of a target.
# Gets only target dependencies, skipping file dependencies.
# @param out - output variable name listing all the dependencies.
# @param TARGET - target to get dependencies for.
function(myci_private_get_all_dependencies out)
    set(options RECURSIVE)
    set(single TARGET)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_TARGET)
        message(FATAL_ERROR "myci_private_get_all_dependencies(): missing mandatory parameter TARGET.")
    endif()

    get_target_property(interface_deps ${arg_TARGET} INTERFACE_LINK_LIBRARIES)
    get_target_property(link_deps ${arg_TARGET} LINK_LIBRARIES)

    set(all_deps)
    if(NOT interface_deps STREQUAL "interface_deps-NOTFOUND")
        list(APPEND all_deps ${interface_deps})
    endif()
    if(NOT link_deps STREQUAL "link_deps-NOTFOUND")
        list(APPEND all_deps ${link_deps})
    endif()

    set(result_deps)
    foreach(dep ${all_deps})
        # skip adding transient dependencies for non-target dependencies
        if(NOT TARGET ${dep})
            continue()
        endif()

        list(APPEND result_deps ${dep})

        if(arg_RECURSIVE)
            # recursively get dependencies of a dependency and add them to the resulting list
            myci_private_get_all_dependencies(dep_deps
                TARGET
                    ${dep}
            )
            foreach(dep_dep ${dep_deps})
                if(NOT TARGET ${dep_dep})
                    continue()
                endif()

                if(NOT "${dep_dep}" IN_LIST result_deps)
                    list(APPEND result_deps ${dep_dep})
                endif()
            endforeach()
        endif()
    endforeach()
    set(${out} ${result_deps} PARENT_SCOPE)
endfunction()

# Generate a resource copying target for each target from DEPENDENCIES
# and add the generated target as dependency to the TARGET.
function(myci_private_add_resource_pack_deps)
    set(options)
    set(single TARGET)
    set(multiple DEPENDENCIES)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT arg_TARGET)
        message(FATAL_ERROR "myci_private_add_resource_pack_deps(): missing mandatory parameter TARGET.")
    endif()

    foreach(dep ${arg_DEPENDENCIES})
        if(NOT IOS)
            string(REPLACE "::" "___" res_target_name "${dep}")
            set(res_target_name ${res_target_name}__${arg_TARGET}__copy_resources)

            if(TARGET ${res_target_name})
                add_dependencies(${arg_TARGET} ${res_target_name})
                continue()
            endif()
        endif()

        # get dependency's resource directory if it has resources
        get_target_property(res_dir "${dep}" myci_resource_directory)
        if(res_dir STREQUAL "res_dir-NOTFOUND")
            get_target_property(res_dir "${dep}" myci_installed_resource_directory_within_datadir)
            if(res_dir STREQUAL "res_dir-NOTFOUND")
                # the dependency does not have resources
                continue()
            endif()
            if(NOT IS_ABSOLUTE ${res_dir})
                message(FATAL_ERROR "myci_private_add_resource_pack_deps(): myci_installed_resource_directory_within_datadir must be absolute path, got ${res_dir}")
            endif()
        else()
            if(NOT IS_ABSOLUTE ${res_dir})
                message(FATAL_ERROR "myci_private_add_resource_pack_deps(): myci_resource_directory property must be an absolute path, got ${res_dir}")
            endif()
        endif()

        if(IOS)
            # On iOS instead of copying resources to the executable output directory we add the resources to the
            # project as source files and mark them as 'Resources', XCode will do the rest.
            target_sources(${arg_TARGET} PRIVATE ${res_dir})
            set_source_files_properties(${res_dir} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        else()
            myci_private_declare_resource_pack(${res_target_name}
                APP_TARGET
                    ${arg_TARGET}
                DIRECTORY
                    ${res_dir}
            )
            add_dependencies(${arg_TARGET} ${res_target_name})
        endif()
    endforeach()
endfunction()

####
# @brief Declare application.
# - Declares application build target
# - Declares run-<name> target to run the application
# @param name - application name.
# @param SOURCES <file1> [<file2> ...] - list of source files. Required.
# @param RESOURCE_DIRECTORY <dir> - application resource directory. The resource directory will be copied to the
#                           application binary output directory.
# @param RUN_ARGUMENTS <arg1> [<arg2> ...] - list of command line arguments to be passed to the application by the run-<name> target. Optional.
# @param DEPENDENCIES <dep1> [<dep2> ...] - list of dependencies. Optional.
#                     If <depX> does not have any '::' in its name, then
#                     it will be searched with find_package(<depX> CONFIG) and if not found then searched with find_package(<depX> MODULE REQUIRED),
#                     and passed to target_link_libraries() as <depX>::<depX>.
#                     If <depX> is in format '<pkg>::<name>' then the <pkg> namespace is treated as package name,
#                     it will be searched with find_package(<pkg> CONFIG) and if not found then searched with find_package(<pkg> MODULE REQUIRED),
#                     and the target will be passed to target_link_libraries() as <depX>.
#                     If <depX> is in format '<pkg>/<target>' then
#                     it will be searched with find_package(<pkg> CONFIG) and if not found then searched with find_package(<pkg> MODULE REQUIRED),
#                     and the target will be passed to target_link_libraries() as <target>.
#                     If <depX> is in format 'PkgConfig::<target>' then
#                     PkgConfig package will be searched with find_package(PkgConfig REQUIRED) and
#                     the target will be added as pkg_check_modules(<target> REQUIRED IMPORTED_TARGET "<target>").
# @param LINUX_ONLY_DEPENDENCIES <dep1> [<dep2> ...] - list of linux-specific dependencies. Optional. Same rules as for DEPENDENCIES apply.
# @param WINDOWS_ONLY_DEPENDENCIES <dep1> [<dep2> ...] - list of windows-specific dependencies. Optional. Same rules as for DEPENDENCIES apply.
# @param INCLUDE_DIRECTORIES <dir1> [<dir2> ...] - include directories. Optional.
# @param GUI - the application is a GUI application, i.e. not a console application.
#              This option only has effect on Windows, on other systems it has no effect.
#              On Windows, inidcates that a generated application will provide WinMain() function instead of main() as entry point.
# @param PREPROCESSOR_DEFINITIONS [<def1>[=<val1>] ...] - preprocessor macro definitions. Optional.
function(myci_declare_application name)
    set(options
        GUI
    )
    set(single
        RESOURCE_DIRECTORY
    )
    set(multiple
        SOURCES
        INCLUDE_DIRECTORIES
        DEPENDENCIES
        LINUX_ONLY_DEPENDENCIES
        WINDOWS_ONLY_DEPENDENCIES
        PREPROCESSOR_DEFINITIONS
        RUN_ARGUMENTS
    )
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    set(gui)
    if(arg_GUI)
        if(WIN32)
            set(gui WIN32)
        elseif(APPLE) # macos or ios
            set(gui MACOSX_BUNDLE)
        endif()
    endif()

    add_executable(${name} ${gui} ${arg_SOURCES})

    # define DEBUG macro for Debug build configuration
    target_compile_definitions(${name} PRIVATE $<$<CONFIG:Debug>:DEBUG>)

    # TODO: allow specifying C++ standard as parameter
    target_compile_features(${name} PRIVATE cxx_std_20)

    set_target_properties(${name} PROPERTIES
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        VS_DEBUGGER_WORKING_DIRECTORY "${myci_private_output_dir}/${name}"
        RUNTIME_OUTPUT_DIRECTORY "${myci_private_output_dir}/${name}"
    )

    # force unicode character set under Visual Studio
    target_compile_definitions(${name} PRIVATE _UNICODE)

    # tell MSVC compiler that sources are in utf-8 encoding
    if(MSVC)
        target_compile_options(${name} PRIVATE "$<$<C_COMPILER_ID:MSVC>:/utf-8>")
        target_compile_options(${name} PRIVATE "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")
    endif()

    target_compile_definitions(${name} PRIVATE ${arg_PREPROCESSOR_DEFINITIONS})

    foreach(dir ${arg_INCLUDE_DIRECTORIES})
        target_include_directories(${name} PRIVATE "${dir}")
    endforeach()

    foreach(lib ${arg_LINK_LIBRARIES})
        target_link_libraries(${name} PRIVATE "${lib}")
    endforeach()

    myci_private_add_target_dependencies(
        TARGET
            ${name}
        VISIBILITY
            PRIVATE
        DEPENDENCIES
            ${arg_DEPENDENCIES}
        LINUX_ONLY_DEPENDENCIES
            ${arg_LINUX_ONLY_DEPENDENCIES}
        WINDOWS_ONLY_DEPENDENCIES
            ${arg_WINDOWS_ONLY_DEPENDENCIES}
    )

    # copy direct application resources
    if(arg_RESOURCE_DIRECTORY)
        if(IOS)
            # On iOS instead of copying resources to the executable output directory we add the resources to the
            # project as source files and mark them as 'Resources', XCode will do the rest.
            target_sources(${name} PRIVATE ${arg_RESOURCE_DIRECTORY})
            set_source_files_properties(${arg_RESOURCE_DIRECTORY} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        else()
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
                APP_TARGET
                    ${name}
                DIRECTORY
                    ${abs_path_directory}
            )
            add_dependencies(${name} ${res_target_name})
        endif()
    endif()

    # copy resources of linked libraries
    myci_private_get_all_dependencies(all_deps
        TARGET
            ${name}
        RECURSIVE
    )
    myci_private_add_resource_pack_deps(
        TARGET
            ${name}
        DEPENDENCIES
            ${all_deps}
    )

    # declare run-<name> target
    add_custom_target(run-${name})
    add_dependencies(run-${name} ${name})

    add_custom_command(TARGET run-${name}
        POST_BUILD
        WORKING_DIRECTORY
            ${myci_private_output_dir}/${name}
        COMMAND
            $<TARGET_FILE:${name}> ${arg_RUN_ARGUMENTS}
    )
endfunction()

####
# @brief Add test target for a test application.
# - Declares a general test target if it is not yet declared.
# - Adds the given application target as a dependency of the general test target.
# @param app_target - name of the test application target.
function(myci_declare_test app_target)
    set(options)
    set(single)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    if(NOT TARGET test)
        add_custom_target(test)
    endif()

    if(NOT TARGET run-${app_target})
        message(FATAL_ERROR "the target run-${app_target} does not exist")
    endif()

    add_dependencies(test run-${app_target})
endfunction()

####
# @brief Add subdirectory if it is not yet added.
# Check if the given directory has beed added and if not just calls add_subdirectory() to add it.
# @param source_dir - path to the directory containing CMakeLists.txt to add.
# @param BINARY_DIR <binary_dir> - the <binary_dir> parameter to be passed to add_subdirectory().
#                                  Required if source_dir is out-of-tree path, e.g. absolute path.
function(myci_add_subdirectory source_dir)
    set(options)
    set(single BINARY_DIR)
    set(multiple)
    cmake_parse_arguments(arg "${options}" "${single}" "${multiple}" ${ARGN})

    file(REAL_PATH
        # PATH
            "${source_dir}"
        # OUTPUT
            abs_source_dir
        BASE_DIRECTORY
            ${CMAKE_CURRENT_LIST_DIR}
        EXPAND_TILDE
    )

    get_property(added_dirs GLOBAL PROPERTY myci_added_subdirectories)

    if(${abs_source_dir} IN_LIST added_dirs)
        # already included
        return()
    endif()

    add_subdirectory(${source_dir} ${arg_BINARY_DIR})

    set_property(GLOBAL APPEND PROPERTY myci_added_subdirectories ${abs_source_dir})
endfunction()
