# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.25)
cmake_policy(VERSION 3.25...3.26)

project(2023-hictk-paper)

include(FetchContent)

FetchContent_Declare(
        CLI11
        URL ${CMAKE_CURRENT_SOURCE_DIR}/external/cli11-v2.3.2.tar.xz
        URL_HASH SHA256=009b7e7a29a4c1768760df470f288e79d746532e5f666776edafb52f18960685
        EXCLUDE_FROM_ALL SYSTEM)

FetchContent_Declare(
        hictk
        URL ${CMAKE_CURRENT_SOURCE_DIR}/external/hictk-aa298d9.tar.xz
        URL_HASH SHA256=192d28d986b42b12947c56f9f1f644cbab58f7f825ac1de2e6d9122c7bcaf838
        EXCLUDE_FROM_ALL SYSTEM)

set(HICTK_BUILD_TOOLS OFF)
set(HICTK_ENABLE_TESTING OFF)
FetchContent_MakeAvailable(CLI11 hictk)

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

add_subdirectory(benchmarks)
add_subdirectory(utils)
