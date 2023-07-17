# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.25)
cmake_policy(VERSION 3.25...3.26)

project(2023-hictk-paper)

include(FetchContent)

FetchContent_Declare(
        hictk
        GIT_REPOSITORY https://github.com/paulsengroup/hictk.git
        GIT_TAG 9fb511b21cc197200d59cacd1fc057c3a6c2d522
        EXCLUDE_FROM_ALL SYSTEM)

set(HICTK_ENABLE_GIT_VERSION_TRACKING OFF)
set(HICTK_BUILD_TOOLS OFF)
set(HICTK_ENABLE_TESTING OFF)
FetchContent_MakeAvailable(hictk)

set(CMAKE_CXX_STANDARD 17)

add_library(benchmarks_project_options INTERFACE)
target_compile_features(benchmarks_project_options INTERFACE cxx_std_${CMAKE_CXX_STANDARD})

include(CheckIPOSupported)
# Optional IPO. Do not use IPO if it's not supported by compiler.
check_ipo_supported(RESULT result OUTPUT output)
if(result)
    message("-- Enabling IPO")
    set_property(TARGET benchmarks_project_options PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
else()
    message(WARNING "-- IPO is not supported: ${output}")
endif()

add_library(benchmarks_project_warnings INTERFACE)
target_compile_options(
        benchmarks_project_warnings
        INTERFACE # C++ warnings
        $<$<COMPILE_LANGUAGE:CXX>:${benchmarks_PROJECT_WARNINGS_CXX}>
        # C warnings
        $<$<COMPILE_LANGUAGE:C>:${benchmarks_PROJECT_WARNINGS_C}>
        # Cuda warnings
        $<$<COMPILE_LANGUAGE:CUDA>:${benchmarks_PROJECT_WARNINGS_CUDA}>)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/CompilerWarnings.cmake)

option(BUILD_BENCHMARKS ON)
option(BUILD_UTILS ON)
if (BUILD_BENCHMARKS)
    add_subdirectory(benchmarks)
endif()

if (BUILD_UTILS)
    add_subdirectory(utils)
endif ()
