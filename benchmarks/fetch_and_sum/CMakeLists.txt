# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

find_package(CLI11 REQUIRED)
find_package(fmt REQUIRED)

add_executable(fetch_and_sum)
target_sources(
  fetch_and_sum PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/fetch_and_sum_hictk.cpp)

target_link_libraries(
  fetch_and_sum
  PRIVATE benchmarks_project_warnings benchmarks_project_options hictk::cooler hictk::hic
        CLI11::CLI11
        PUBLIC
        fmt::fmt
)

target_include_directories(fetch_and_sum PRIVATE include)

install(
  TARGETS fetch_and_sum
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
