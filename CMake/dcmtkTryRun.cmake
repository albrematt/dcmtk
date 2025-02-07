#
# Wrapper implementation of try_run(), with some support for
# cross-compiling
#
# Usage and syntax is equivalent to CMake's try_run().
#

# CMakeParseArguments was introduced in CMake 2.8.3.
# DCMTK_TRY_RUN will revert to CMake's internal try_run()
# for versions prior to 2.8.3, as arguments can't be parsed
# in that case. This means cross compiling support will be
# disabled for CMake versions prior to 2.8.3.
if(CMAKE_VERSION VERSION_LESS 2.8.3)

macro(DCMTK_TRY_RUN)
    try_run(${ARGN})
endmacro()

else()

include(CMakeParseArguments)

function(DCMTK_TRY_RUN_CROSS RUN_RESULT_VAR COMPILE_RESULT_VAR bindir srcfile)
    set(PASSTHROUGH_ARGS COMPILE_DEFINITIONS LINK_LIBRARIES)
    cmake_parse_arguments(DCMTK_TRY_RUN
            ""
            "COMPILE_OUTPUT_VARIABLE;RUN_OUTPUT_VARIABLE;OUTPUT_VARIABLE"
            "CMAKE_FLAGS;${PASSTHROUGH_ARGS};ARGS"
            ${ARGN}
    )
    get_filename_component(OUTPUT_EXECUTABLE_NAME "${srcfile}" NAME)
    set(OUTPUT_EXECUTABLE_NAME "${OUTPUT_EXECUTABLE_NAME}${CMAKE_EXECUTABLE_SUFFIX}")
    set(OUTPUT_EXECUTABLE "${bindir}/${OUTPUT_EXECUTABLE_NAME}")
    set(TRY_COMPILE_ARGS "${COMPILE_RESULT_VAR}" "${bindir}" "${srcfile}")
    if(DCMTK_TRY_RUN_CMAKE_FLAGS)
        list(APPEND TRY_COMPILE_ARGS CMAKE_FLAGS ${DCMTK_TRY_RUN_CMAKE_FLAGS} ${DCMTK_TRY_COMPILE_REQUIRED_CMAKE_FLAGS})
    elseif(DCMTK_TRY_COMPILE_REQUIRED_CMAKE_FLAGS)
        list(APPEND TRY_COMPILE_ARGS CMAKE_FLAGS ${DCMTK_TRY_COMPILE_REQUIRED_CMAKE_FLAGS})
    endif()
    foreach(ARG ${PASSTHROUGH_ARGS})
        if(DCMTK_TRY_RUN_${ARG})
            list(APPEND TRY_COMPILE_ARGS "${ARG}" ${DCMTK_TRY_RUN_${ARG}})
        endif()
    endforeach()
    if(DCMTK_TRY_RUN_COMPILE_OUTPUT_VARIABLE)
        list(APPEND TRY_COMPILE_ARGS OUTPUT_VARIABLE ${DCMTK_TRY_RUN_COMPILE_OUTPUT_VARIABLE})
    endif()
    try_compile(${TRY_COMPILE_ARGS} COPY_FILE "${OUTPUT_EXECUTABLE}")
    set("${COMPILE_RESULT_VAR}" ${${COMPILE_RESULT_VAR}} PARENT_SCOPE)
    if(DCMTK_TRY_RUN_COMPILE_OUTPUT_VARIABLE)
        set("${DCMTK_TRY_RUN_COMPILE_OUTPUT_VARIABLE}" ${${DCMTK_TRY_RUN_COMPILE_OUTPUT_VARIABLE}} PARENT_SCOPE)
    endif()
    if(${COMPILE_RESULT_VAR})
        if(WIN32)
            WINE_COMMAND(CMD "${OUTPUT_EXECUTABLE}" ${DCMTK_TRY_RUN_ARGS})
            WINE_DETACHED("${RUN_RESULT_VAR}" "${DCMTK_TRY_RUN_RUN_OUTPUT_VARIABLE}" "${DCMTK_TRY_RUN_RUN_OUTPUT_VARIABLE}" "${WINE_WINE_PROGRAM}" ${CMD})
        elseif(ANDROID)
            DCMTK_ANDROID_WAIT_FOR_EMULATOR(DCMTK_ANDROID_EMULATOR_INSTANCE)
            if(NOT DCMTK_TRY_RUN_ANDROID_RUNTIME_INSTALLED)
                DCMTK_ANDROID_FIND_RUNTIME_LIBRARIES(ANDROID_RUNTIME_LIBRARIES)
                set(ANDROID_RUNTIME_LIBRARIES ${ANDROID_RUNTIME_LIBRARIES} CACHE INTERNAL "")
                DCMTK_ANDROID_PUSH(DCMTK_ANDROID_EMULATOR_INSTANCE ${ANDROID_RUNTIME_LIBRARIES} DESTINATION "${ANDROID_TEMPORARY_FILES_LOCATION}")
                set(DCMTK_TRY_RUN_ANDROID_RUNTIME_INSTALLED TRUE CACHE INTERNAL "")
            endif()
            DCMTK_ANDROID_PUSH(DCMTK_ANDROID_EMULATOR_INSTANCE "${OUTPUT_EXECUTABLE}" DESTINATION "${ANDROID_TEMPORARY_FILES_LOCATION}/${OUTPUT_EXECUTABLE_NAME}")
            DCMTK_ANDROID_SHELL(DCMTK_ANDROID_EMULATOR_INSTANCE
                COMMAND chmod 755 "${ANDROID_TEMPORARY_FILES_LOCATION}/${OUTPUT_EXECUTABLE_NAME}"
                OUTPUT_QUIET
                ERROR_QUIET
            )
            DCMTK_ANDROID_SHELL(DCMTK_ANDROID_EMULATOR_INSTANCE
                COMMAND "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${ANDROID_TEMPORARY_FILES_LOCATION}" "${ANDROID_TEMPORARY_FILES_LOCATION}/${OUTPUT_EXECUTABLE_NAME}" ${DCMTK_TRY_RUN_ARGS}
                RESULT_VARIABLE "${RUN_RESULT_VAR}"
                OUTPUT_VARIABLE "${DCMTK_TRY_RUN_RUN_OUTPUT_VARIABLE}"
                ERROR_VARIABLE "${DCMTK_TRY_RUN_RUN_OUTPUT_VARIABLE}"
            )
        else()
            message(WARNING "Emulation for your target platform is not available, please fill in the required configure test results manually.")
            try_run("${RUN_RESULT_VAR}" "${COMPILE_RESULT_VAR}" "${bindir}" "${srcfile}" ${ARGN})
            return()
        endif()
        set("${RUN_RESULT_VAR}" ${${RUN_RESULT_VAR}} PARENT_SCOPE)
        set("${DCMTK_TRY_RUN_RUN_OUTPUT_VARIABLE}" ${${DCMTK_TRY_RUN_RUN_OUTPUT_VARIABLE}} PARENT_SCOPE)
    endif()
endfunction()

macro(DCMTK_TRY_RUN)
    if(DCMTK_CROSS_COMPILING)
        DCMTK_TRY_RUN_CROSS(${ARGN})
    else()
        try_run(${ARGN})
    endif()
endmacro()

endif()
