# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

find_package(absl REQUIRED)
find_package(fmt REQUIRED)

add_executable(4dn_pairs_to_txt)
target_sources(4dn_pairs_to_txt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/4dn_pairs_to_txt.cpp)

target_link_libraries(
  4dn_pairs_to_txt
  PRIVATE utils_project_warnings utils_project_options
  PUBLIC absl::strings fmt::fmt)

target_include_directories(4dn_pairs_to_txt PRIVATE include/)

install(
  TARGETS 4dn_pairs_to_txt
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
