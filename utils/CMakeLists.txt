# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.18)
cmake_policy(VERSION 3.18...3.26)

project(
  utils
  LANGUAGES CXX
  VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/CompilerWarnings.cmake)

add_library(utils_project_options INTERFACE)
target_compile_features(utils_project_options INTERFACE cxx_std_${CMAKE_CXX_STANDARD})

include(CheckIPOSupported)
# Optional IPO. Do not use IPO if it's not supported by compiler.
check_ipo_supported(RESULT result OUTPUT output)
if(result)
  message("-- Enabling IPO")
  set_property(TARGET utils_project_options PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
else()
  message(WARNING "-- IPO is not supported: ${output}")
endif()

add_library(utils_project_warnings INTERFACE)
target_compile_options(
  utils_project_warnings
  INTERFACE # C++ warnings
            $<$<COMPILE_LANGUAGE:CXX>:${utils_PROJECT_WARNINGS_CXX}>
            # C warnings
            $<$<COMPILE_LANGUAGE:C>:${utils_PROJECT_WARNINGS_C}>
            # Cuda warnings
            $<$<COMPILE_LANGUAGE:CUDA>:${utils_PROJECT_WARNINGS_CUDA}>)

add_subdirectory(4dn_pairs_to_txt)
